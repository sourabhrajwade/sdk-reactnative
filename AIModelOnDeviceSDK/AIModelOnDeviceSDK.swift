//
//  AIModelOnDeviceSDK.swift
//  AIModelOnDeviceSDK
//
//  Created on 14/11/25.
//
//  AIModelOnDeviceSDK - On-Device AI Model Inference SDK
//
//  This SDK provides on-device AI capabilities for:
//  - Interior image verification with quality scoring
//  - Object detection using YOLO models
//  - Batch processing support
//
//  Installation:
//  - Swift Package Manager: Add as local package or via URL
//  - Manual: Copy SDK folder and add to Xcode project
//
//  Usage:
//  ```swift
//  import AIModelOnDeviceSDK
//  let sdk = AIModelOnDeviceSDK.shared
//  sdk.verifyInteriorImage(image) { result in ... }
//  ```
//
//  See README.md for complete documentation.

import Foundation
import UIKit
import SwiftUI

/// Main SDK entry point for AI Model On Device operations
///
/// This class provides a singleton interface to all SDK functionality.
/// All methods are thread-safe and can be called from any thread.
///
/// ## Usage
///
/// ```swift
/// import AIModelOnDeviceSDK
///
/// let sdk = AIModelOnDeviceSDK.shared
///
/// // Verify interior image
    /// sdk.verifyInteriorImage(image, using: .yolov3) { result in
///     print("Valid: \(result.isValid), Score: \(result.score)")
/// }
///
/// // Detect objects
/// sdk.detectObjects(image) { detections, latency in
///     print("Found \(detections?.count ?? 0) objects")
/// }
/// ```
///
/// ## Requirements
///
/// - iOS 13.0+
/// - Models must be included in app bundle (in Resources/models/)
/// - No external dependencies required
///
/// ## Thread Safety
///
/// All methods are thread-safe. Completion handlers are called on the same
/// thread/queue where the method was invoked.
///
/// ## See Also
///
/// - `README.md` - Complete documentation and examples
/// - `YOLOModel` - Available model types
/// - `VerificationResult` - Verification result structure
/// - `DetectionResult` - Object detection result structure
public class AIModelOnDeviceSDK {
    
    /// Shared instance
    public static let shared = AIModelOnDeviceSDK()
    
    var sdkOptions = SDKOptions(persionalisationType: .all, photoSelectionType: .auto)
    
    private init() {}
    
    /// Clear model cache
    ///
    /// Removes all cached YOLO models from memory. Use this when:
    /// - Memory is constrained
    /// - Switching between many different models
    /// - Before app termination (optional)
    ///
    /// ## Note
    ///
    /// Models will be reloaded on next use, which may cause a slight delay.
    /// Caching improves performance for repeated model usage.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Clear cache when done processing
    /// sdk.clearCache()
    ///
    /// // Or before switching models
    /// sdk.clearCache()
    /// sdk.detectObjects(image, using: .yolov3) { ... }
    /// ```
    ///
    /// ## See Also
    ///
    /// Models are automatically cached after first load. This method allows
    /// manual cache management for memory optimization.
    public func clearCache() {
        ObjectDetectionModelHandler.shared.clearCache()
    }

    
    /// Generate room images from tagger results
    ///
    /// This method takes tagger API results and generates room images by combining
    /// room photos with object images (bed, sofa, table) based on room categories.
    ///
    /// ## Parameters
    ///
    /// - `taggerResult: TaggerCompleteResult` - Result from tagger API (required)
    /// - `objectImages: [String: UIImage]` - Dictionary mapping object labels to images (required)
    ///   - Keys: "bed", "sofa", "table"
    ///   - Values: UIImage objects for each object
    /// - `completion: @escaping (Result<RoomGenerationCompleteResult, Error>) -> Void` - Completion handler (required)
    ///
    /// ## Returns
    ///
    /// `Void` - Results are provided via the completion handler
    ///
    /// ## RoomGenerationCompleteResult Properties
    ///
    /// - `results: [RoomGenerationResult]` - Array of generated room images
    ///   - Each result contains: category, roomImage, objectImage, generatedImage, roomType
    /// - `totalGenerated: Int` - Number of successfully generated images
    ///
    /// ## Mapping
    ///
    /// - `living_room` → uses "sofa" image
    /// - `bedroom` → uses "bed" image
    /// - `dining_room` → uses "table" image
    ///
    /// ## Example
    ///
    /// ```swift
    /// let objectImages: [String: UIImage] = [
    ///     "bed": bedImage,
    ///     "sofa": sofaImage,
    ///     "table": tableImage
    /// ]
    ///
    /// sdk.generateRooms(from: taggerResult, objectImages: objectImages) { result in
    ///     switch result {
    ///     case .success(let roomResults):
    ///         print("Generated \(roomResults.totalGenerated) room images")
    ///         for roomResult in roomResults.results {
    ///             // Use roomResult.generatedImage
    ///         }
    ///     case .failure(let error):
    ///         print("Error: \(error.localizedDescription)")
    ///     }
    /// }
    /// ```
    ///
    /// ## Thread Safety
    ///
    /// This method is thread-safe. The completion handler is called on the main queue.
    ///
    /// - Parameters:
    ///   - taggerResult: Tagger API result
    ///   - objectImages: Dictionary of object images
    ///   - completion: Completion handler with result
    public func generateFurniture(
        roomType: String,
        roomImageUrl: String? = nil,
        objectUrl: String,
        objectImage: UIImage? = nil,
        completion: @escaping (Result<PersionalisationImageResult, Error>) -> Void
    ) {
        if let cachedImage = TempCacheHandler.shared.getThumbnail(forProductUrl: objectUrl) {
            completion(.success(PersionalisationImageResult(productUrl: objectUrl, resultImage: cachedImage)))
        }else {
            TaggerAPIHandler.shared.generateRoom(roomType: roomType,objectUrl: objectUrl, completion: completion)
        }
    }
    
    public func generateFashion(
        garmentImageUrl: String,
        productType:String,
        categorySlug:String,
        completion: @escaping (Result<PersionalisationImageResult, Error>) -> Void
    ) {
        if let cachedImage = TempCacheHandler.shared.getThumbnail(forProductUrl: garmentImageUrl) {
            completion(.success(PersionalisationImageResult(productUrl: garmentImageUrl, resultImage: cachedImage)))
        }else {
            TaggerAPIHandler.shared.generateFashion( garmentImageUrl: garmentImageUrl, productType: productType,categorySlug:categorySlug, completion: completion)
        }
    }
    
    func persionalizeFashionPhoto(arrImage:[UIImage],category:String,complition:@escaping(String) -> Void) async throws {
        do {
            try await FashionPersonalizationService.shared.fetchBestFashionPhotoFromRemote(clusterImages: arrImage,progressUpdate: complition)
        }catch let err {
            throw err
        }
    }
    
    func persionalizeFurniturePhoto(arrImage:[UIImage],category:String,complition:@escaping(String) -> Void) async throws {
        do {
            try await SDKPersonalizationService.shared.fetchBestFurniturePhotoFromRemote(clusterImages: arrImage, progressUpdate: complition)
        }catch let err {
            throw err
        }
    }
    
    public func isPersionalizeRoomPhotoEmpty() -> Bool {
        ImageStorageHandler.shared.isRoomImagesEmpty()
    }
    
    public func isPersionalizeUserPhotoEmpty() -> Bool {
        ImageStorageHandler.shared.isUserImagesEmpty()
    }
}

