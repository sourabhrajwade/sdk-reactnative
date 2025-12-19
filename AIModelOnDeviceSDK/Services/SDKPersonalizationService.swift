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
    
    private let sdk = AIModelOnDeviceSDK.shared
    private let clusterService = PhotoClusterService.shared
    
    private init() {
        // Load productImageMap from persistent storage
    }
    
    
    /// Runs the complete personalization pipeline
    func runPersonalizationPipeline(
        progressUpdate: @escaping (String) -> Void
    ) async throws {
        // Always clear cache at the start of personalization
        print("🗑️ Clearing old personalized images from cache...")
        //LogWriter.shared.write("🗑️ Clearing old personalized images from cache...")
        print("✅ Cache cleared - starting personalization pipeline")
        //LogWriter.shared.write("✅ Cache cleared - starting personalization pipeline")
        
        progressUpdate("Fetching photos from gallery...")
        
        // Step 1: Fetch photos with location
        let (photos, photoClusters) = try await clusterService.fetchPhotosWithLocationCached(
            limit: 1000,
            radius: 500.0,
            forceRefresh: true
        )
        
        guard !photos.isEmpty else {
            throw PersonalizationError.noPhotosFound
        }
        
        progressUpdate("Selecting best photos...")
        
        // Step 2: Select largest cluster
        guard let largestCluster = clusterService.getLargestCluster(from: photoClusters) else {
            throw PersonalizationError.insufficientPhotos
        }
        
        // Step 3: Load images from cluster
        var clusterImages: [UIImage] = []
        var clusterIdentifiers: [String] = []
        let batchSize = 10
        
        for batchStart in stride(from: 0, to: largestCluster.photos.count, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, largestCluster.photos.count)
            let batch = Array(largestCluster.photos[batchStart..<batchEnd])
            
            var batchImages: [UIImage] = []
            var batchIdentifiers: [String] = []
            
            for photoLocation in batch {
                if let image = await clusterService.loadImage(from: photoLocation.asset) {
                    batchImages.append(image)
                    batchIdentifiers.append(photoLocation.asset.localIdentifier)
                }
            }
            
            autoreleasepool {
                clusterImages.append(contentsOf: batchImages)
                clusterIdentifiers.append(contentsOf: batchIdentifiers)
            }
        }
        
        guard !clusterImages.isEmpty else {
            throw PersonalizationError.failedToLoadImages
        }
        
        progressUpdate("Analyzing images...")
        
        do {
            try await fetchBestFurniturePhotoFromRemote(clusterImages: clusterImages) { msg in
                progressUpdate(msg)
            }
        }catch let err {
            throw err
        }
    }
    
    func fetchBestFurniturePhotoFromRemote(clusterImages:[UIImage] , progressUpdate: @escaping (String) -> Void) async throws {
        // Step 4: Filter top 15 images by score
        let topResults = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[ImageVerificationResult], Error>) in
            InteriorVerificationHandler.shared.filterResults(clusterImages, using: .yolov3) { results in
                continuation.resume(returning: results)
            }
        }
        
        guard !topResults.isEmpty else {
            throw PersonalizationError.noValidImages
        }
        
        progressUpdate("Tagging images...")
        
        // Step 5: Tag images with API
        var imagesWithIDs: [ImageWithID] = []
        for result in topResults {
            let identifier = "image_\(result.index)"
            imagesWithIDs.append(ImageWithID(
                image: result.image,
                identifier: identifier
            ))
        }
        
        let taggerResult = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<TaggerCompleteResult, Error>) in
            TaggerAPIHandler.shared.tagImages(imagesWithIDs) { result in
                switch result {
                case .success(let taggerResult):
                    continuation.resume(returning: taggerResult)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
        
        progressUpdate("Generating personalized room images...")
        
        for tagresult in taggerResult.bestPicks {
            if let image = imagesWithIDs.filter({$0.identifier == tagresult.identifier}).first?.image {
                ImageStorageHandler.shared.saveBestHomeRoomImage(image, withName: tagresult.category.rawValue)
            }
        }
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



