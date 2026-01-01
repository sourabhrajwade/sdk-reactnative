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
    
    func runPersonalizationPipeline(progressUpdate: @escaping (SDKState) -> Void,completion : @escaping (Result<SDKResult, Error>) -> Void) async throws {
        let (photoClusters) = try await clusterService.fetchAllPHAssets()
        return try await filterPhotos(photoClusters: photoClusters, progressUpdate: progressUpdate, completion: completion)
    }
    
    func runPersonalizationPipelineWith(
        arrPHAssets: [PHAsset],
        progressUpdate: @escaping (SDKState) -> Void,
        completion : @escaping (Result<SDKResult, Error>) -> Void
    ) async throws {
        progressUpdate(.analyzing)
        
        let (photoClusters) = try await clusterService.fetchAllPhotosWithImages(allAssets: arrPHAssets)
        return try await filterPhotos(photoClusters: photoClusters, progressUpdate: progressUpdate, completion: completion)
    }
    
    private func filterPhotos(photoClusters:[PhotoDetectionData],progressUpdate: @escaping (SDKState) -> Void,
                              completion : @escaping (Result<SDKResult, Error>) -> Void) async throws {
        guard !photoClusters.isEmpty else {
            throw PersonalizationError.noPhotosFound
        }
        progressUpdate(SDKState.clustering)
        let topResults = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[PhotoDetectionData], Error>) in
            InteriorVerificationHandler.shared.filterPhotoResults(photoClusters, using: .yolov3) { results in
                continuation.resume(returning: results)
            }
        }
        print(topResults.count)
        
        return try await self.filterAllTypePhotos(topResults: topResults, progressUpdate: progressUpdate, completion: completion)
    }
    
    func filterAllTypePhotos(topResults:[PhotoDetectionData],progressUpdate: @escaping (SDKState) -> Void,
                             completion : @escaping (Result<SDKResult, Error>) -> Void) async throws{
        progressUpdate(SDKState.selectingBestPhoto)
        var arrbedroom : [PhotoDetectionData] = []
        var arrlivingRoom : [PhotoDetectionData] = []
        var arrdiningRoom : [PhotoDetectionData] = []
        var arrMalePerson : [PhotoDetectionData] = []
        var arrFeMalePerson : [PhotoDetectionData] = []
        
        topResults.forEach { data in
            if let roomCategory = data.photoVerificationResult?.validCategory {
                switch  roomCategory {
                case .bed_room:
                    arrbedroom.append(data)
                case .living_room:
                    arrlivingRoom.append(data)
                case .dining_room:
                    arrdiningRoom.append(data)
                case .male:
                    arrMalePerson.append(data)
                case .female:
                    arrFeMalePerson.append(data)
                default:
                    break
                }
            }
        }
        var arrPersonalizeAsset : [PersonalizedAsset] = []
        
        print("arrbedroom = ",arrbedroom.count)
        if let bedroomPhoto = arrbedroom.sorted(by: {$0.photoVerificationResult?.score ?? 0.0 > $1.photoVerificationResult?.score ?? 0.0}).first {
            let personalizedAsset = PersonalizedAsset(phAsset: bedroomPhoto.phAsset,validCategory: bedroomPhoto.photoVerificationResult?.validCategory ?? .unknown)
            arrPersonalizeAsset.append(personalizedAsset)
        }
        print("arrlivingRoom = ",arrlivingRoom.count)
        if let livingroomPhoto = arrlivingRoom.sorted(by: {$0.photoVerificationResult?.score ?? 0.0 > $1.photoVerificationResult?.score ?? 0.0}).first {
            let personalizedAsset = PersonalizedAsset(phAsset: livingroomPhoto.phAsset,validCategory: livingroomPhoto.photoVerificationResult?.validCategory ?? .unknown)
            arrPersonalizeAsset.append(personalizedAsset)
        }
        print("arrdiningRoom = ",arrdiningRoom.count)
        if let diningroomPhoto = arrdiningRoom.sorted(by: {$0.photoVerificationResult?.score ?? 0.0 > $1.photoVerificationResult?.score ?? 0.0}).first {
            let personalizedAsset = PersonalizedAsset(phAsset: diningroomPhoto.phAsset,validCategory: diningroomPhoto.photoVerificationResult?.validCategory ?? .unknown)
            arrPersonalizeAsset.append(personalizedAsset)
        }
        print("arrPerson = ",arrMalePerson.count)
        if let personPhoto = arrMalePerson.sorted(by: {$0.photoVerificationResult?.score ?? 0.0 > $1.photoVerificationResult?.score ?? 0.0}).first {
            let personalizedAsset = PersonalizedAsset(phAsset: personPhoto.phAsset,validCategory: personPhoto.photoVerificationResult?.validCategory ?? .unknown)
            arrPersonalizeAsset.append(personalizedAsset)
        }
        print("arrPerson = ",arrFeMalePerson.count)
        if let personPhoto = arrFeMalePerson.sorted(by: {$0.photoVerificationResult?.score ?? 0.0 > $1.photoVerificationResult?.score ?? 0.0}).first {
            let personalizedAsset = PersonalizedAsset(phAsset: personPhoto.phAsset,validCategory: personPhoto.photoVerificationResult?.validCategory ?? .unknown)
            arrPersonalizeAsset.append(personalizedAsset)
        }
        progressUpdate(SDKState.complete)
        let sdkResult = SDKResult(success: true, message: "Personalize completed", arrPersonalizeAsset: arrPersonalizeAsset)
        completion(.success(sdkResult))
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



