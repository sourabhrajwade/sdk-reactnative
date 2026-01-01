//
//  PhotoClusterService.swift
//  HPIkeaSampleApp
//
//  Service for clustering photos by location
//

import Foundation
import Photos
import CoreLocation
import UIKit
import PhotosUI

struct PhotoVerificationResult {
    var isValid: Bool = false
    var validCategory: TaggerAPIResultCategory?
    var score: Double = 0.0
    var arrDetectionResult : [DetectionResult]?
    var scoreBreakdown: ScoreBreakdown?
    var totalLatency: Double = 0.0
    
    var status: String {
        return isValid ? "✅ Valid Interior Image" : "❌ Invalid Image"
    }
    
    public init() {}
}
/// Category of verification
public enum VerificationCategory: String, Codable {
    case interior
    case person
    case unknown
}
class PhotoDetectionData {
    let phAsset : PHAsset
    let image : UIImage
    var photoVerificationResult : PhotoVerificationResult?
    
    init(phAsset: PHAsset, image: UIImage) {
        self.phAsset = phAsset
        self.image = image
    }
}


// Service for clustering photos by location
final class PhotoClusterService {
    
    
    
    
    init() {
    }
    
    
    
    // MARK: - Fetch Photos
    
    func fetchAllPHAssets() async throws -> ([PhotoDetectionData]){
        // Request authorization (using older API for read-only access)
        let status = await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        
        guard status == .authorized || status == .limited else {
            throw PhotoClusterError.authorizationDenied
        }
        
        // Combine gallery assets with additionally selected assets
        var allAssets: [PHAsset] = []
        
        // Fetch assets from gallery
        let fetchOptions = PHFetchOptions()
        fetchOptions.fetchLimit = 500
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        
        let assets = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        allAssets = Array(_immutableCocoaArray: assets)
        return try await fetchAllPhotosWithImages(allAssets: allAssets)
    }
    func fetchAllPhotosWithImages(allAssets:[PHAsset]) async throws -> ([PhotoDetectionData]) {
        
        
        // Step 3: Load images from cluster
        var clusterImages: [PhotoDetectionData] = []
        let batchSize = 10
        
        for batchStart in stride(from: 0, to: allAssets.count, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, allAssets.count)
            let batch = Array(allAssets[batchStart..<batchEnd])
            
            var batchImages: [PhotoDetectionData] = []
            
            for phasset in batch {
                if let image = await PhotoClusterService().loadImageOfAsset(from: phasset) {
                    batchImages.append(PhotoDetectionData(phAsset: phasset, image: image))
                }
            }
            
            autoreleasepool {
                clusterImages.append(contentsOf: batchImages)
            }
        }
        
        return clusterImages
    }
    
    func loadImageOfAsset(from asset: PHAsset) async -> UIImage? {
        return await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .opportunistic
            options.resizeMode = .fast
            options.isSynchronous = false
            
            var hasResumed = false
            let lock = NSLock()
            
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: PHImageManagerMaximumSize,
                contentMode: .default,
                options: options
            ) { image, info in
                lock.lock()
                defer { lock.unlock() }
                
                if hasResumed { return }
                
                if let cancelled = info?[PHImageCancelledKey] as? Bool, cancelled {
                    if !hasResumed {
                        hasResumed = true
                        continuation.resume(returning: nil)
                    }
                    return
                }
                
                if image != nil {
                    if !hasResumed {
                        hasResumed = true
                        continuation.resume(returning: image)
                    }
                } else if let error = info?[PHImageErrorKey] as? Error {
                    if !hasResumed {
                        hasResumed = true
                        continuation.resume(returning: nil)
                    }
                }
            }
        }
    }
    
}

// Error types
enum PhotoClusterError: LocalizedError {
    case authorizationDenied
    case noPhotosFound
    case noClustersFound
    case userCancelled
    case noViewController
    
    var errorDescription: String? {
        switch self {
        case .authorizationDenied:
            return "Photo library access denied. Please grant permission in Settings."
        case .noPhotosFound:
            return "No photos with location data found in your gallery."
        case .noClustersFound:
            return "No photo clusters found with the specified criteria."
        case .userCancelled:
            return "Photo selection was cancelled by user."
        case .noViewController:
            return "Could not find current view controller to present dialog."
        }
    }
}

