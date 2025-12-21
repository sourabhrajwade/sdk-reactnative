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

// Photo with location data
struct PhotoLocation: Identifiable {
    let id: String
    let asset: PHAsset
    let latitude: Double
    let longitude: Double
    var image: UIImage?
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

// Cluster of photos
struct PhotoCluster: Identifiable {
    let id = UUID()
    let photos: [PhotoLocation]
    let centroid: CLLocationCoordinate2D
    
    var photoCount: Int {
        photos.count
    }
}

// Service for clustering photos by location
final class PhotoClusterService {
    
    
    
    
    init() {
    }
    
    
    
    // MARK: - Fetch Photos
    func fetchAllPhotos() async throws -> ([PhotoCluster]) {
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
        fetchOptions.fetchLimit = 500
        
        let assets = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        allAssets = Array(_immutableCocoaArray: assets)
        
        return try await fetchPhotosWithLocation(arrPHAssets: allAssets)
    }
    /// Fetch photos with location (with caching support)
    func fetchPhotosWithLocation(arrPHAssets:[PHAsset]) async throws -> ([PhotoCluster]) {
        let photos = try await fetchPhotos(arrPHAssets:arrPHAssets)
        let clusters = clusterPhotos(photos)
        return (clusters)
    }
    /// Fetch photos with location from gallery using Swift 6 concurrent task groups
    func fetchPhotos(arrPHAssets:[PHAsset]) async throws -> [PhotoLocation] {
        
        // Use Swift 6 concurrent task groups to fetch photos with locations
        return try await withThrowingTaskGroup(of: PhotoLocation?.self) { group in
            var photos: [PhotoLocation] = []
            
            // Process each asset concurrently
            for asset in arrPHAssets {
                group.addTask {
                    // Check if asset has location
                    if AIModelOnDeviceSDK.shared.sdkOptions.photoSelectionType == .auto {
                        guard let location = asset.location else {
                            return nil
                        }
                        
                        // Create PhotoLocation (without image initially for performance)
                        return PhotoLocation(
                            id: asset.localIdentifier,
                            asset: asset,
                            latitude: location.coordinate.latitude,
                            longitude: location.coordinate.longitude,
                            image: nil
                        )
                    }else {
                        // Create PhotoLocation (without image initially for performance)
                        return PhotoLocation(
                            id: asset.localIdentifier,
                            asset: asset,
                            latitude: 23.0,
                            longitude: 24.0,
                            image: nil
                        )
                    }
                }
            }
            
            // Collect results
            for try await photoLocation in group {
                if let photo = photoLocation {
                    photos.append(photo)
                }
            }
            
            print("✅ Found \(photos.count) photos with GPS data out of \(arrPHAssets.count) total")
            //LogWriter.shared.write("✅ Found \(photos.count) photos with GPS data out of \(allAssets.count) total")
            return photos
        }
    }
    
    
    /// Cluster photos that are geographically close
    func clusterPhotos(_ photos: [PhotoLocation]) -> [PhotoCluster] {
        var clusters: [PhotoCluster] = []
        var unclustered = photos
        
        while let photo = unclustered.first {
            let photoLocation = CLLocation(latitude: photo.latitude, longitude: photo.longitude)
            
            // Find all photos within radius
            let clusterGroup = unclustered.filter { otherPhoto in
                let otherLocation = CLLocation(latitude: otherPhoto.latitude, longitude: otherPhoto.longitude)
                let distance = photoLocation.distance(from: otherLocation)
                return distance < AIModelOnDeviceSDK.shared.sdkOptions.locationRadius
            }
            
            if !clusterGroup.isEmpty {
                // Compute centroid
                let avgLat = clusterGroup.map { $0.latitude }.reduce(0, +) / Double(clusterGroup.count)
                let avgLon = clusterGroup.map { $0.longitude }.reduce(0, +) / Double(clusterGroup.count)
                
                let cluster = PhotoCluster(
                    photos: clusterGroup,
                    centroid: CLLocationCoordinate2D(latitude: avgLat, longitude: avgLon)
                )
                clusters.append(cluster)
                
                // Remove clustered photos from the pool
                let clusteredIds = Set(clusterGroup.map { $0.id })
                unclustered.removeAll { clusteredIds.contains($0.id) }
            } else {
                unclustered.removeFirst()
            }
        }
        
        // Sort clusters by photo count (descending)
        clusters.sort { $0.photoCount > $1.photoCount }
        
        print("✅ Created \(clusters.count) clusters")
        //LogWriter.shared.write("✅ Created \(clusters.count) clusters")
        return clusters
    }
    
    /// Get the largest cluster (cluster with most photos)
    func getLargestCluster(from clusters: [PhotoCluster]) -> PhotoCluster? {
        return clusters.max(by: { $0.photoCount < $1.photoCount })
    }
    
    /// Get clusters above a minimum photo count threshold
    func getClustersAboveThreshold(_ clusters: [PhotoCluster], minimumPhotoCount: Int) -> [PhotoCluster] {
        return clusters.filter { $0.photoCount >= minimumPhotoCount }
    }
    
    func loadImage(from asset: PHAsset, targetSize : CGSize = CGSize(width: 1024, height: 1024)) async -> UIImage? {
        return await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .opportunistic
            options.resizeMode = .fast
            options.isSynchronous = false
            
            let aspectRatio = CGFloat(asset.pixelWidth) / CGFloat(asset.pixelHeight)
            let size: CGSize
            if aspectRatio > 1 {
                size = CGSize(width: 1024, height: 1024 / aspectRatio)
            } else {
                size = CGSize(width: 1024 * aspectRatio, height: 1024)
            }
            
            var hasResumed = false
            let lock = NSLock()
            
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: size,
                contentMode: .aspectFit,
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

// MARK: - Photo Picker Coordinator

/// Coordinator to handle PHPickerViewController delegate
private class PhotoPickerCoordinator: NSObject, PHPickerViewControllerDelegate {
    private let completion: ([PHPickerResult]) -> Void
    
    init(completion: @escaping ([PHPickerResult]) -> Void) {
        self.completion = completion
        super.init()
    }
    
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        completion(results)
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

