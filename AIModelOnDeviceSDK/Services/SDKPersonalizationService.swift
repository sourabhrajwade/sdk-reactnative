//
//  SDKPersonalizationService.swift
//  HPIkeaSampleApp
//
//  Created by Vinit Chapla on 16/12/25.
//

import Foundation
import UIKit
import Photos



final class SDKPersonalizationService {
    static let shared = SDKPersonalizationService()
    
    let clusterService = PhotoClusterService()
    
    private init() {
        // Load productImageMap from persistent storage
    }
    
    /// Runs the complete personalization pipeline
    func runPersonalizationPipeline(progressUpdate: @escaping (SDKState) -> Void,
                                    complition : @escaping (Result<SDKResult, Error>) -> Void
                                ) async throws {
        let (photoClusters) = try await clusterService.fetchAllPhotos()
        return try await runPhotoCluster(photoClusters: photoClusters, progressUpdate: progressUpdate, complition: complition)
    }
    
    func runPersonalizationPipelineWith(
        arrPHAssesst: [PHAsset],
        progressUpdate: @escaping (SDKState) -> Void,
        complition : @escaping (Result<SDKResult, Error>) -> Void
    ) async throws {
        progressUpdate(.clusturing)
    
        let (photoClusters) = try await clusterService.fetchPhotosWithLocation(arrPHAssets: arrPHAssesst)
        return try await runPhotoCluster(photoClusters: photoClusters, progressUpdate: progressUpdate, complition: complition)
    }
    
    func runPhotoCluster(
        photoClusters:[PhotoCluster],
        progressUpdate: @escaping (SDKState) -> Void,
        complition : @escaping (Result<SDKResult, Error>) -> Void
    ) async throws {
        // Always clear cache at the start of personalization
        print("🗑️ Clearing old personalized images from cache...")
        //LogWriter.shared.write("🗑️ Clearing old personalized images from cache...")
        print("✅ Cache cleared - starting personalization pipeline")
        //LogWriter.shared.write("✅ Cache cleared - starting personalization pipeline")
        
        // Step 1: Fetch photos with location
        
        guard !photoClusters.isEmpty else {
            throw PersonalizationError.noPhotosFound
        }
        
        // Step 2: Select largest cluster
        guard let largestCluster = clusterService.getLargestCluster(from: photoClusters) else {
            throw PersonalizationError.insufficientPhotos
        }
        
        // Step 3: Load images from cluster
        var clusterImages: [ClusterImage] = []
        let batchSize = 10
        
        for batchStart in stride(from: 0, to: largestCluster.photos.count, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, largestCluster.photos.count)
            let batch = Array(largestCluster.photos[batchStart..<batchEnd])
            
            var batchImages: [ClusterImage] = []
            
            for photoLocation in batch {
                if let image = await clusterService.loadImageOfAsset(from: photoLocation.asset) {
                    batchImages.append(ClusterImage(identifier: photoLocation.asset.localIdentifier, image: image))
                }
            }
            
            autoreleasepool {
                clusterImages.append(contentsOf: batchImages)
            }
        }
        
        guard !clusterImages.isEmpty else {
            throw PersonalizationError.failedToLoadImages
        }
        
        progressUpdate(.analyzing)
        switch AIModelOnDeviceSDK.shared.sdkOptions.persionalisationType {
        case .all :
            do {
                var arrHomeGoodsAssest : [PersionalizeAssest] = []
                var arrFashionAssest : [PersionalizeAssest] = []
                try await fetchBestFurniturePhotoFromRemote(clusterImages: clusterImages) { state in
                    progressUpdate(state)
                } complition: { result in
                    let harrAsset = result.compactMap { bestPick in
                        return PersionalizeAssest(phAsset: largestCluster.photos.first(where: {$0.asset.localIdentifier == bestPick.identifier})?.asset, bestPickResult: bestPick)
                    }
                    arrHomeGoodsAssest.append(contentsOf: harrAsset)
                }
                try await fetchBestFashionPhotoFromRemote(clusterImages: clusterImages) { state in
                    progressUpdate(state)
                } complition: { result in
                    let farrAsset = result.compactMap { bestPick in
                        return PersionalizeAssest(phAsset: largestCluster.photos.first(where: {$0.asset.localIdentifier == bestPick.identifier})?.asset, bestPickResult: bestPick)
                    }
                    arrFashionAssest.append(contentsOf: farrAsset)
                }
                let sdkResult = SDKResult(success: true, message: "", arrHomeGoodsAssest: arrHomeGoodsAssest , arrFashionAssest: arrFashionAssest)
                complition(.success(sdkResult))
            }catch let err {
                throw err
            }
            
        case .homegoods :
            do {
                var arrAsset : [PersionalizeAssest] = []
                try await fetchBestFurniturePhotoFromRemote(clusterImages: clusterImages) { state in
                    progressUpdate(state)
                } complition: { result in
                    let harrAsset = result.compactMap { bestPick in
                        return PersionalizeAssest(phAsset: largestCluster.photos.first(where: {$0.asset.localIdentifier == bestPick.identifier})?.asset, bestPickResult: bestPick)
                    }
                    arrAsset.append(contentsOf: harrAsset)
                }
                
                let sdkResult = SDKResult(success: true, message: "", arrHomeGoodsAssest: arrAsset , arrFashionAssest: nil)
                complition(.success(sdkResult))
            }catch let err {
                throw err
            }
        case .fashion :
            do {
                var arrAsset : [PersionalizeAssest] = []
                try await fetchBestFashionPhotoFromRemote(clusterImages: clusterImages) { state in
                    progressUpdate(state)
                } complition: { result in
                    let farrAsset = result.compactMap { bestPick in
                        return PersionalizeAssest(phAsset: largestCluster.photos.first(where: {$0.asset.localIdentifier == bestPick.identifier})?.asset, bestPickResult: bestPick)
                    }
                    arrAsset.append(contentsOf: farrAsset)
                }
                let sdkResult = SDKResult(success: true, message: "", arrHomeGoodsAssest: nil , arrFashionAssest: arrAsset)
                complition(.success(sdkResult))
            }catch let err {
                throw err
            }
        case .unKnown:
            break
        }
    }
    
    func fetchBestFurniturePhotoFromRemote(clusterImages:[ClusterImage] , progressUpdate: @escaping (SDKState) -> Void,complition:@escaping ([BestPickResult]) -> Void) async throws {
        // Step 4: Filter top 15 images by score
        let topResults = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[ImageVerificationResult], Error>) in
            InteriorVerificationHandler.shared.filterResults(clusterImages, using: .yolov3) { results in
                continuation.resume(returning: results)
            }
        }
        
        guard !topResults.isEmpty else {
            throw PersonalizationError.noValidImages
        }
        
        progressUpdate(.tagging)
        
        let topClusterImgs = topResults.compactMap({$0.image})
        
        let taggerResult = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<TaggerCompleteResult, Error>) in
            TaggerAPIHandler.shared.tagImages(topClusterImgs) { result in
                switch result {
                case .success(let taggerResult):
                    continuation.resume(returning: taggerResult)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
        
        progressUpdate(.complete)
        complition(taggerResult.bestPicks)
    }
    
    func fetchBestFashionPhotoFromRemote(clusterImages:[ClusterImage] , progressUpdate: @escaping (SDKState) -> Void,complition:@escaping ([BestPickResult]) -> Void) async throws {
        // Step 4: Find best face images using FaceVerificationHandler (similar to PersonalizationService Step 4)
        let faceResults = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[FaceObservationData], Error>) in
            FaceVerificationHandler.shared.filterResults(clusterImages) { results in
                continuation.resume(returning: results)
            }
        }

        guard !faceResults.isEmpty else {
            throw PersonalizationError.noValidImages
        }

        // Pick the face that appears most frequently, then take the highest-quality image for that face.
        // (This uses 512-D embeddings generated by the SDK.)
        var arrBestResult : [BestPickResult] = []
        let menFaceResults = faceResults.compactMap { observationData in
            return (observationData.category == .male) ? observationData : nil
        }
        if menFaceResults.count > 0 {
            let picked = FaceVerificationHandler.shared.bestImageForMostFrequentFace(from: menFaceResults, similarityThreshold: 0.80)
            guard let bestFace = picked?.best else {
                throw PersonalizationError.noValidFaceFound
            }

            
            progressUpdate(.tagging)
            
            guard let bestImg = picked?.best else {
                print("⚠️ Failed to best face image")
                // //LogWriter.shared.write("⚠️ Failed to best face image")
                return
            }
            arrBestResult.append(BestPickResult(category: bestImg.category.rawValue, image: bestImg.image, imageUrl: nil, identifier: bestImg.identifier, bestPick: BestPick(filename: "\(bestImg.category.rawValue).jpg", score: bestImg.qualityScore, id: 1, imageUrl: nil)))
        }
        
        let womenFaceResults = faceResults.compactMap { observationData in
            return (observationData.category == .female) ? observationData : nil
        }
        if womenFaceResults.count > 0 {
            let picked = FaceVerificationHandler.shared.bestImageForMostFrequentFace(from: womenFaceResults, similarityThreshold: 0.80)
            guard let bestFace = picked?.best else {
                throw PersonalizationError.noValidFaceFound
            }
            progressUpdate(.tagging)
            
            guard let bestImg = picked?.best else {
                print("⚠️ Failed to best face image")
                //LogWriter.shared.write("⚠️ Failed to best face image")
                return
            }
            arrBestResult.append(BestPickResult(category: bestImg.category.rawValue, image: bestImg.image, imageUrl: nil, identifier: bestImg.identifier, bestPick: BestPick(filename: "\(bestImg.category.rawValue).jpg", score: bestImg.qualityScore, id: 1, imageUrl: nil)))
        }
        progressUpdate(.complete)
        complition(arrBestResult)
    }
}

// MARK: - Helper Types

struct SDKCategoryMapping {
    let category: SDKCategory
    let taggerCategory: String
    let bestPicks: [BestPickResult]
}

enum SDKPersonalizationError: LocalizedError {
    case noPhotosFound
    case insufficientPhotos
    case failedToLoadImages
    case noValidImages
    case noImagesForCategory
    case noValidFaceFound
    
    var errorDescription: String? {
        switch self {
        case .noPhotosFound:
            return "No photos with location data found"
        case .insufficientPhotos:
            return "Not enough photos in cluster"
        case .failedToLoadImages:
            return "Failed to load images from cluster"
        case .noValidImages:
            return "No valid images found after filtering"
        case .noImagesForCategory:
            return "No images available for this category"
        case .noValidFaceFound:
            return "No valid face found in images"
        }
    }
}



