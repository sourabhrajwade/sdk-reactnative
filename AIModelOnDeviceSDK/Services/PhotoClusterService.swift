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

// Codable version for caching (without PHAsset and UIImage)
struct CachedPhotoLocation: Codable {
    let id: String
    let assetId: String
    let latitude: Double
    let longitude: Double
    
    init(from photoLocation: PhotoLocation) {
        self.id = photoLocation.id
        self.assetId = photoLocation.asset.localIdentifier
        self.latitude = photoLocation.latitude
        self.longitude = photoLocation.longitude
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

// Codable version for caching
struct CachedPhotoCluster: Codable {
    let id: String
    let photoIds: [String]
    let centroidLatitude: Double
    let centroidLongitude: Double
    let photoCount: Int
    
    init(from cluster: PhotoCluster) {
        self.id = cluster.id.uuidString
        self.photoIds = cluster.photos.map { $0.id }
        self.centroidLatitude = cluster.centroid.latitude
        self.centroidLongitude = cluster.centroid.longitude
        self.photoCount = cluster.photoCount
    }
}

// Cache data structure
struct PhotoClusterCache: Codable {
    let photos: [CachedPhotoLocation]
    let clusters: [CachedPhotoCluster]
    let radius: Double
    let timestamp: Date
    let photoLimit: Int
}

// Service for clustering photos by location
final class PhotoClusterService {
    
    static let shared = PhotoClusterService()
    
    private let cacheDirectory: URL
    private let cacheFileName = "photo_cluster_cache.json"
    
    private init() {
        // Set up cache directory
        let fileManager = FileManager.default
        let cacheDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheDirectory = cacheDir.appendingPathComponent("PhotoClusterCache", isDirectory: true)
        
        // Create cache directory if it doesn't exist
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
    
    // MARK: - Cache Management
    
    private var cacheURL: URL {
        cacheDirectory.appendingPathComponent(cacheFileName)
    }
    
    /// Save clustering results to cache
    func saveCache(photos: [PhotoLocation], clusters: [PhotoCluster], radius: Double, limit: Int) {
        let cachedPhotos = photos.map { CachedPhotoLocation(from: $0) }
        let cachedClusters = clusters.map { CachedPhotoCluster(from: $0) }
        
        let cache = PhotoClusterCache(
            photos: cachedPhotos,
            clusters: cachedClusters,
            radius: radius,
            timestamp: Date(),
            photoLimit: limit
        )
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(cache)
            try data.write(to: cacheURL)
            print("✅ Cache saved: \(clusters.count) clusters, \(photos.count) photos")
            //LogWriter.shared.write("✅ Cache saved: \(clusters.count) clusters, \(photos.count) photos")
        } catch {
            print("❌ Failed to save cache: \(error.localizedDescription)")
            //LogWriter.shared.write("❌ Failed to save cache: \(error.localizedDescription)")
        }
    }
    
    /// Load clustering results from cache
    func loadCache(radius: Double, limit: Int) -> (photos: [PhotoLocation], clusters: [PhotoCluster])? {
        guard FileManager.default.fileExists(atPath: cacheURL.path) else {
            return nil
        }
        
        do {
            let data = try Data(contentsOf: cacheURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let cache = try decoder.decode(PhotoClusterCache.self, from: data)
            
            // Check if cache is valid (same radius and limit)
            guard cache.radius == radius && cache.photoLimit == limit else {
                print("⚠️ Cache invalid: radius or limit mismatch")
                //LogWriter.shared.write("⚠️ Cache invalid: radius or limit mismatch")
                return nil
            }
            
            // Check cache age (invalidate after 24 hours)
            let cacheAge = Date().timeIntervalSince(cache.timestamp)
            if cacheAge > 24 * 60 * 60 {
                print("⚠️ Cache expired (older than 24 hours)")
                //LogWriter.shared.write("⚠️ Cache expired (older than 24 hours)")
                return nil
            }
            
            // Reconstruct PHAssets from asset IDs
            let assetIds = cache.photos.map { $0.assetId }
            let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: assetIds, options: nil)
            
            // Create a dictionary for quick lookup
            var assetDict: [String: PHAsset] = [:]
            fetchResult.enumerateObjects { asset, _, _ in
                assetDict[asset.localIdentifier] = asset
            }
            
            // Reconstruct PhotoLocation objects
            var photos: [PhotoLocation] = []
            for cachedPhoto in cache.photos {
                guard let asset = assetDict[cachedPhoto.assetId] else {
                    print("⚠️ Asset not found: \(cachedPhoto.assetId)")
                    //LogWriter.shared.write("⚠️ Asset not found: \(cachedPhoto.assetId)")
                    continue
                }
                
                let photoLocation = PhotoLocation(
                    id: cachedPhoto.id,
                    asset: asset,
                    latitude: cachedPhoto.latitude,
                    longitude: cachedPhoto.longitude,
                    image: nil
                )
                photos.append(photoLocation)
            }
            
            // Reconstruct PhotoCluster objects
            var clusters: [PhotoCluster] = []
            for cachedCluster in cache.clusters {
                let clusterPhotos = photos.filter { cachedCluster.photoIds.contains($0.id) }
                guard !clusterPhotos.isEmpty else { continue }
                
                let cluster = PhotoCluster(
                    photos: clusterPhotos,
                    centroid: CLLocationCoordinate2D(
                        latitude: cachedCluster.centroidLatitude,
                        longitude: cachedCluster.centroidLongitude
                    )
                )
                clusters.append(cluster)
            }
            
            print("✅ Cache loaded: \(clusters.count) clusters, \(photos.count) photos")
            //LogWriter.shared.write("✅ Cache loaded: \(clusters.count) clusters, \(photos.count) photos")
            return (photos, clusters)
        } catch {
            print("❌ Failed to load cache: \(error.localizedDescription)")
            //LogWriter.shared.write("❌ Failed to load cache: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Clear cache
    func clearCache() {
        try? FileManager.default.removeItem(at: cacheURL)
        print("🗑️ Cache cleared")
        //LogWriter.shared.write("🗑️ Cache cleared")
    }
    
    /// Check if valid cache exists
    func hasValidCache(radius: Double, limit: Int) -> Bool {
        return loadCache(radius: radius, limit: limit) != nil
    }
    
    // MARK: - Photo Selection Dialog
    
    /// Get the current top view controller from the window scene
    @MainActor
    private func getCurrentViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first(where: { $0.isKeyWindow }),
              let rootViewController = window.rootViewController else {
            return nil
        }
        
        return getTopViewController(from: rootViewController)
    }
    
    /// Recursively find the top-most view controller
    @MainActor
    private func getTopViewController(from viewController: UIViewController) -> UIViewController {
        if let presented = viewController.presentedViewController {
            return getTopViewController(from: presented)
        }
        
        if let navigationController = viewController as? UINavigationController {
            if let topVC = navigationController.topViewController {
                return getTopViewController(from: topVC)
            }
        }
        
        if let tabBarController = viewController as? UITabBarController {
            if let selected = tabBarController.selectedViewController {
                return getTopViewController(from: selected)
            }
        }
        
        return viewController
    }
    
    /// Show dialog to select more photos or continue with existing photos
    /// Automatically finds the current view controller from the window scene
    /// - Returns: True if user wants to continue, False if cancelled
    @MainActor
    func showPhotoSelectionDialog() async throws -> Bool {
        if AIModelOnDeviceSDK.shared.sdkOptions.photoSelectionType == .auto {
            return true
        }
        
        guard let viewController = getCurrentViewController() else {
            print("❌ Could not find current view controller")
            //LogWriter.shared.write("❌ Could not find current view controller")
            throw PhotoClusterError.noViewController
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let alert = UIAlertController(
                title: "Photo Selection",
                message: "Choose how you want to select photos:",
                preferredStyle: .actionSheet
            )
            
            // "Select Photos" option - opens photo picker
            alert.addAction(UIAlertAction(title: "Select Photos", style: .default) { _ in
                Task { @MainActor in
                    do {
                        let selectedAssets = try await self.presentPhotoPicker()
                        if !selectedAssets.isEmpty {
                            print("✅ User selected \(selectedAssets.count) photos")
                            //LogWriter.shared.write("✅ User selected \(selectedAssets.count) photos")
                            // Store selected assets for later use
                            self.additionalSelectedAssets = selectedAssets
                        }
                        continuation.resume(returning: true)
                    } catch {
                        print("❌ Error selecting photos: \(error.localizedDescription)")
                        //LogWriter.shared.write("❌ Error selecting photos: \(error.localizedDescription)")
                        continuation.resume(throwing: error)
                    }
                }
            })
            
            // "Select Album" option - shows album picker
            alert.addAction(UIAlertAction(title: "Select Album", style: .default) { _ in
                Task { @MainActor in
                    do {
                        let selectedAssets = try await self.presentAlbumPicker()
                        if !selectedAssets.isEmpty {
                            print("✅ User selected album with \(selectedAssets.count) photos")
                            //LogWriter.shared.write("✅ User selected album with \(selectedAssets.count) photos")
                            // Store selected assets for later use
                            self.additionalSelectedAssets = selectedAssets
                        }
                        continuation.resume(returning: true)
                    } catch {
                        print("❌ Error selecting album: \(error.localizedDescription)")
                        //LogWriter.shared.write("❌ Error selecting album: \(error.localizedDescription)")
                        continuation.resume(throwing: error)
                    }
                }
            })
            
            // "Continue" option - proceed with existing photos
//            alert.addAction(UIAlertAction(title: "Auto Fetch All Photos", style: .default) { _ in
//                print("✅ User chose to continue with gallery photos")
//                LogWriter.shared.write("✅ User chose to continue with gallery photos")
//                continuation.resume(returning: true)
//            })
//            
//            // "Cancel" option
//            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
//                print("⚠️ User cancelled photo selection")
//                LogWriter.shared.write("⚠️ User cancelled photo selection")
//                continuation.resume(returning: false)
//            })
            
            // For iPad - set source view
            if let popoverController = alert.popoverPresentationController {
                popoverController.sourceView = viewController.view
                popoverController.sourceRect = CGRect(x: viewController.view.bounds.midX, 
                                                     y: viewController.view.bounds.midY, 
                                                     width: 0, height: 0)
                popoverController.permittedArrowDirections = []
            }
            
            viewController.present(alert, animated: true)
        }
    }
    
    /// Present photo picker to select additional photos
    /// Automatically finds the current view controller from the window scene
    /// - Returns: Array of selected PHAssets
    @MainActor
    private func presentPhotoPicker() async throws -> [PHAsset] {
        guard let viewController = getCurrentViewController() else {
            print("❌ Could not find current view controller")
            //LogWriter.shared.write("❌ Could not find current view controller")
            throw PhotoClusterError.noViewController
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            var configuration = PHPickerConfiguration(photoLibrary: .shared())
            configuration.selectionLimit = 0 // 0 = unlimited
            configuration.filter = .images
            
            let picker = PHPickerViewController(configuration: configuration)
            
            // Create a coordinator to handle the picker delegate
            let coordinator = PhotoPickerCoordinator { results in
                var assets: [PHAsset] = []
                
                for result in results {
                    if let assetId = result.assetIdentifier {
                        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil)
                        if let asset = fetchResult.firstObject {
                            assets.append(asset)
                        }
                    }
                }
                
                continuation.resume(returning: assets)
            }
            
            picker.delegate = coordinator
            // Store coordinator to prevent deallocation
            objc_setAssociatedObject(picker, "coordinator", coordinator, .OBJC_ASSOCIATION_RETAIN)
            
            viewController.present(picker, animated: true)
        }
    }
    
    /// Present album picker to select an entire album
    /// Automatically finds the current view controller from the window scene
    /// - Returns: Array of PHAssets from the selected album
    @MainActor
    private func presentAlbumPicker() async throws -> [PHAsset] {
        guard let viewController = getCurrentViewController() else {
            print("❌ Could not find current view controller")
            //LogWriter.shared.write("❌ Could not find current view controller")
            throw PhotoClusterError.noViewController
        }
        
        // Fetch all albums
        let userAlbums = PHAssetCollection.fetchAssetCollections(
            with: .album,
            subtype: .any,
            options: nil
        )
        
        let smartAlbums = PHAssetCollection.fetchAssetCollections(
            with: .smartAlbum,
            subtype: .any,
            options: nil
        )
        
        // Combine albums
        var albums: [PHAssetCollection] = []
        userAlbums.enumerateObjects { collection, _, _ in
            albums.append(collection)
        }
        smartAlbums.enumerateObjects { collection, _, _ in
            // Filter out some system albums
            let excludedSubtypes: [PHAssetCollectionSubtype] = [
                .smartAlbumAllHidden
            ]
            if !excludedSubtypes.contains(collection.assetCollectionSubtype) {
                albums.append(collection)
            }
        }
        
        guard !albums.isEmpty else {
            print("⚠️ No albums found")
            //LogWriter.shared.write("⚠️ No albums found")
            return []
        }
        
        // Show album selection dialog
        return try await withCheckedThrowingContinuation { continuation in
            let alert = UIAlertController(
                title: "Select Album",
                message: "Choose an album to import all photos:",
                preferredStyle: .actionSheet
            )
            
            // Add action for each album
            for album in albums {
                let fetchOptions = PHFetchOptions()
                fetchOptions.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.image.rawValue)
                let assets = PHAsset.fetchAssets(in: album, options: fetchOptions)
                
                let title = "\(album.localizedTitle ?? "Unknown") (\(assets.count) photos)"
                
                alert.addAction(UIAlertAction(title: title, style: .default) { _ in
                    // Fetch all assets from selected album
                    var albumAssets: [PHAsset] = []
                    assets.enumerateObjects { asset, _, _ in
                        albumAssets.append(asset)
                    }
                    
                    print("✅ Selected album '\(album.localizedTitle ?? "Unknown")' with \(albumAssets.count) photos")
                    //LogWriter.shared.write("✅ Selected album '\(album.localizedTitle ?? "Unknown")' with \(albumAssets.count) photos")
                    
                    continuation.resume(returning: albumAssets)
                })
            }
            
            // Cancel option
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
                print("⚠️ User cancelled album selection")
                //LogWriter.shared.write("⚠️ User cancelled album selection")
                continuation.resume(returning: [])
            })
            
            // For iPad - set source view
            if let popoverController = alert.popoverPresentationController {
                popoverController.sourceView = viewController.view
                popoverController.sourceRect = CGRect(x: viewController.view.bounds.midX,
                                                     y: viewController.view.bounds.midY,
                                                     width: 0, height: 0)
                popoverController.permittedArrowDirections = []
            }
            
            viewController.present(alert, animated: true)
        }
    }
    
    // Store additional selected assets
    private var additionalSelectedAssets: [PHAsset] = []
    
    // MARK: - Fetch Photos
    
    /// Fetch photos with location from gallery using Swift 6 concurrent task groups
    func fetchPhotosWithLocation(limit: Int = 1000) async throws -> [PhotoLocation] {
        // Request authorization (using older API for read-only access)
        let status = await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        
        guard status == .authorized || status == .limited else {
            throw PhotoClusterError.authorizationDenied
        }
        // Step 1: Show dialog to select more photos
        let shouldContinue = try await showPhotoSelectionDialog()
        
        guard shouldContinue else {
            throw PhotoClusterError.userCancelled
        }
        // Combine gallery assets with additionally selected assets
        var allAssets: [PHAsset] = []
        
        if additionalSelectedAssets.isEmpty {
            // Fetch assets from gallery
            let fetchOptions = PHFetchOptions()
            fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            fetchOptions.fetchLimit = limit
            
            let assets = PHAsset.fetchAssets(with: .image, options: fetchOptions)
            // Add gallery assets
            for index in 0..<assets.count {
                allAssets.append(assets.object(at: index))
            }
        }else{
            // Add additionally selected assets (from photo picker)
            print("📸 Adding \(additionalSelectedAssets.count) user-selected photos to gallery photos")
            //LogWriter.shared.write("📸 Adding \(additionalSelectedAssets.count) user-selected photos to gallery photos")
            allAssets.append(contentsOf: additionalSelectedAssets)
            // Clear after use
            additionalSelectedAssets = []
        }
        
        // Use Swift 6 concurrent task groups to fetch photos with locations
        return try await withThrowingTaskGroup(of: PhotoLocation?.self) { group in
            var photos: [PhotoLocation] = []
            
            // Process each asset concurrently
            for asset in allAssets {
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
            
            print("✅ Found \(photos.count) photos with GPS data out of \(allAssets.count) total")
            //LogWriter.shared.write("✅ Found \(photos.count) photos with GPS data out of \(allAssets.count) total")
            return photos
        }
    }
    
    /// Load images for photo locations using concurrent task groups
    func loadImages(for photos: [PhotoLocation], targetSize: CGSize = CGSize(width: 1024, height: 1024)) async throws -> [PhotoLocation] {
        return try await withThrowingTaskGroup(of: PhotoLocation.self) { group in
            var photosWithImages: [PhotoLocation] = []
            
            for photo in photos {
                group.addTask {
                    // Load image from asset
                    let image = await self.loadImage(from: photo.asset, targetSize: targetSize)
                    return PhotoLocation(
                        id: photo.id,
                        asset: photo.asset,
                        latitude: photo.latitude,
                        longitude: photo.longitude,
                        image: image
                    )
                }
            }
            
            // Collect results
            for try await photoWithImage in group {
                photosWithImages.append(photoWithImage)
            }
            
            return photosWithImages
        }
    }
    
    /// Load image from PHAsset
    private func loadImage(from asset: PHAsset, targetSize: CGSize) async -> UIImage? {
        return await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isSynchronous = false
            options.isNetworkAccessAllowed = true
            
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFit,
                options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }
    
    /// Fetch photos with location - with dialog option to select more photos
    /// Automatically finds the current view controller from the window scene
    /// - Parameter limit: Maximum number of photos to fetch from gallery
    /// - Returns: Array of PhotoLocation objects
    @MainActor
    func fetchPhotosWithLocationAndDialog(limit: Int = 1000) async throws -> [PhotoLocation] {
        
        // Step 2: Fetch assets (includes any additionally selected photos)
        return try await fetchPhotosWithLocation(limit: limit)
    }
    
    /// Fetch photos with location (with caching support)
    func fetchPhotosWithLocationCached(limit: Int = 1000, radius: Double = 500, forceRefresh: Bool = false) async throws -> ([PhotoLocation], [PhotoCluster]) {
        // Check cache first (unless force refresh is requested)
        if !forceRefresh, let cached = loadCache(radius: radius, limit: limit) {
            print("✅ Using cached clustering results")
            //LogWriter.shared.write("✅ Using cached clustering results")
            return cached
        }
        
        // Cache miss or force refresh - fetch and cluster
        if forceRefresh {
            print("🔄 Force refresh - fetching from gallery (ignoring cache)...")
            //LogWriter.shared.write("🔄 Force refresh - fetching from gallery (ignoring cache)...")
        } else {
            print("📥 Cache miss - fetching from gallery...")
            //LogWriter.shared.write("📥 Cache miss - fetching from gallery...")
        }
        
        let photos = try await fetchPhotosWithLocationAndDialog(limit: limit)
        let clusters = clusterPhotos(photos, within: radius)
        
        // Save to cache
        saveCache(photos: photos, clusters: clusters, radius: radius, limit: limit)
        
        return (photos, clusters)
    }
    
    func fetchPhotos(limit: Int = 1000) async throws -> ([PhotoLocation]) {
        let photos = try await fetchPhotosWithLocationAndDialog(limit: limit)

        return photos
    }
    
    /// Cluster photos that are geographically close
    func clusterPhotos(_ photos: [PhotoLocation], within radiusMeters: Double = 500) -> [PhotoCluster] {
        var clusters: [PhotoCluster] = []
        var unclustered = photos
        
        while let photo = unclustered.first {
            let photoLocation = CLLocation(latitude: photo.latitude, longitude: photo.longitude)
            
            // Find all photos within radius
            let clusterGroup = unclustered.filter { otherPhoto in
                let otherLocation = CLLocation(latitude: otherPhoto.latitude, longitude: otherPhoto.longitude)
                let distance = photoLocation.distance(from: otherLocation)
                return distance < radiusMeters
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
    
    func loadImage(from asset: PHAsset) async -> UIImage? {
        return await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .opportunistic
            options.resizeMode = .fast
            options.isSynchronous = false
            
            let targetSize = CGSize(width: 1024, height: 1024)
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

