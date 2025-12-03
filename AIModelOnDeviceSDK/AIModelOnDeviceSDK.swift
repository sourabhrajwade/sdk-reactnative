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
    
    private init() {}
    
    /// Verify if an image is a valid interior image
    ///
    /// This method performs comprehensive verification of interior room images by:
    /// 1. Detecting objects using YOLO models
    /// 2. Applying 10 filter checks (confidence, coverage, spread, etc.)
    /// 3. Calculating a quality score (0.0 - 1.0)
    /// 4. Returning detailed results with filter breakdowns
    ///
    /// ## Parameters
    ///
    /// - `image`: The UIImage to verify (required)
    /// - `modelType`: YOLO model to use (optional, default: `.yolov3`)
    ///   - `.yolov3` - Classic YOLO3 model
    /// - `completion`: Completion handler called with `VerificationResult`
    ///
    /// ## Returns
    ///
    /// `Void` - Results are provided via the completion handler
    ///
    /// ## VerificationResult Properties
    ///
    /// - `isValid: Bool` - Whether image passed all checks
    /// - `score: Double` - Quality score (0.0 - 1.0), only valid if `isValid == true`
    /// - `detections: [DetectionResult]` - All detected objects
    /// - `filterResults: [FilterResult]` - Individual filter check results
    /// - `scoreBreakdown: ScoreBreakdown?` - Detailed score breakdown (if valid)
    /// - `totalLatency: Double` - Total processing time in milliseconds
    ///
    /// ## Example
    ///
    /// ```swift
    /// sdk.verifyInteriorImage(image, using: .yolov3) { result in
    ///     if result.isValid {
    ///         print("✅ Valid interior! Score: \(result.score)")
    ///         // Access detailed breakdown
    ///         if let breakdown = result.scoreBreakdown {
    ///             print("Furniture: \(breakdown.furnitureCoverageScore)")
    ///             print("Spread: \(breakdown.spreadScore)")
    ///         }
    ///     } else {
    ///         print("❌ Invalid image")
    ///         // Check which filters failed
    ///         for filter in result.filterResults where !filter.passed {
    ///             print("Failed: \(filter.name) - \(filter.message)")
    ///         }
    ///     }
    /// }
    /// ```
    ///
    /// ## Thread Safety
    ///
    /// This method is thread-safe. The completion handler is called on the same
    /// thread/queue where the method was invoked.
    ///
    /// - Parameters:
    ///   - image: The image to verify
    ///   - modelType: The YOLO model to use for object detection (default: .yolov3)
    ///   - completion: Completion handler with VerificationResult
    public func verifyInteriorImage(_ image: UIImage, using modelType: YOLOModel = .yolov3, completion: @escaping (VerificationResult) -> Void) {
        InteriorVerificationHandler.shared.verifyInteriorImage(image, using: modelType, completion: completion)
    }
    
    /// Filter and return top 15 images sorted by highest score from scoreBreakdown
    ///
    /// This method verifies multiple images and returns the top 15 images sorted by
    /// their scoreBreakdown.finalScore (highest first). Only valid images with
    /// scoreBreakdown are included in the results.
    ///
    /// ## Parameters
    ///
    /// - `images`: Array of UIImage objects to verify and filter (required)
    /// - `modelType`: YOLO model to use (optional, default: `.yolov3`)
    /// - `completion`: Completion handler called with array of top 15 `ImageVerificationResult`
    ///
    /// ## Returns
    ///
    /// `Void` - Results are provided via the completion handler
    ///
    /// ## ImageVerificationResult Properties
    ///
    /// Each result contains:
    /// - `image: UIImage` - The original image
    /// - `result: VerificationResult` - Full verification result with scoreBreakdown
    /// - `index: Int` - Original index in the input array
    ///
    /// ## Example
    ///
    /// ```swift
    /// let images: [UIImage] = [...] // Your array of images
    /// sdk.filterResults(images, using: .yolo11n) { topResults in
    ///     print("Top \(topResults.count) images by score:")
    ///     for (index, imageResult) in topResults.enumerated() {
    ///         if let score = imageResult.result.scoreBreakdown?.finalScore {
    ///             print("\(index + 1). Score: \(score)")
    ///         }
    ///     }
    /// }
    /// ```
    ///
    /// ## Thread Safety
    ///
    /// This method is thread-safe. The completion handler is called on the main queue.
    ///
    /// - Parameters:
    ///   - images: Array of images to verify and filter
    ///   - modelType: The YOLO model to use for object detection (default: .yolov3)
    ///   - completion: Completion handler with top 15 ImageVerificationResult sorted by score (highest first)
    public func filterResults(_ images: [UIImage], using modelType: YOLOModel = .yolov3, completion: @escaping ([ImageVerificationResult]) -> Void) {
        InteriorVerificationHandler.shared.filterResults(images, using: modelType, completion: completion)
    }
    
    /// Detect objects in an image using YOLO models
    ///
    /// This method detects objects in an image using the specified YOLO model.
    /// Models are automatically cached after first load for improved performance.
    ///
    /// ## Parameters
    ///
    /// - `image`: The UIImage to analyze (required)
    /// - `modelType`: YOLO model to use (optional, default: `.yolov3`)
    /// - `completion`: Completion handler with:
    ///   - First parameter: `[DetectionResult]?` - Array of detections, or `nil` if failed
    ///   - Second parameter: `Double?` - Processing latency in milliseconds, or `nil` if failed
    ///
    /// ## Returns
    ///
    /// `Void` - Results are provided via the completion handler
    ///
    /// ## DetectionResult Properties
    ///
    /// Each detection contains:
    /// - `label: String` - Object name (e.g., "chair", "person", "table")
    /// - `confidence: Float` - Confidence score (0.0 - 1.0)
    /// - `boundingBox: BoundingBox` - Normalized coordinates (0.0 - 1.0)
    /// - `areaPercentage: Float` - Area percentage of image
    ///
    /// ## Example
    ///
    /// ```swift
    /// sdk.detectObjects(image, using: .yolo11n) { detections, latency in
    ///     guard let detections = detections else {
    ///         print("Detection failed")
    ///         return
    ///     }
    ///
    ///     print("Found \(detections.count) objects in \(latency ?? 0)ms")
    ///
    ///     for detection in detections {
    ///         print("\(detection.label): \(detection.confidencePercentage)")
    ///         print("Position: x=\(detection.boundingBox.x), y=\(detection.boundingBox.y)")
    ///     }
    /// }
    /// ```
    ///
    /// ## Performance
    ///
    /// Typical processing times:
    /// - YOLOv3: ~150-250ms
    ///
    /// Times vary based on device, image size, and number of objects.
    ///
    /// - Parameters:
    ///   - image: The image to analyze
    ///   - modelType: The YOLO model to use (default: .yolov3)
    ///   - completion: Completion handler with detection results and latency
    public func detectObjects(_ image: UIImage, using modelType: YOLOModel = .yolov3, completion: @escaping ([DetectionResult]?, Double?) -> Void) {
        ObjectDetectionModelHandler.shared.detectObjects(image, using: modelType, completion: completion)
    }
    
    /// Get face embedding from an image using FaceNet
    /// - Parameter image: The image containing a face
    /// - Returns: Tuple containing embedding array and latency in milliseconds, or nil if failed
    /// NOTE: This method is disabled - TensorFlow dependency removed
    // public func getFaceEmbedding(from image: UIImage) -> (embedding: [Float], latency: Double)? {
    //     // FaceNet functionality disabled - TensorFlow dependency removed
    //     let handler = FaceNetModelHandler()
    //     return handler.getEmbedding(from: image)
    // }
    
    /// Annotate image with bounding boxes from detections
    ///
    /// Draws bounding boxes and labels on the image based on detection results.
    /// Boxes are color-coded by confidence level:
    /// - Green: > 80% confidence
    /// - Yellow: 50-80% confidence
    /// - Orange: < 50% confidence
    ///
    /// ## Parameters
    ///
    /// - `image`: The original UIImage to annotate (required)
    /// - `detections`: Array of `DetectionResult` objects (required, non-empty)
    ///
    /// ## Returns
    ///
    /// `UIImage?` - Annotated image with bounding boxes and labels, or `nil` if failed
    ///
    /// ## Example
    ///
    /// ```swift
    /// sdk.detectObjects(image) { detections, _ in
    ///     guard let detections = detections else { return }
    ///
    ///     if let annotated = sdk.annotateImage(image, with: detections) {
    ///         imageView.image = annotated
    ///     }
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - image: The original image
    ///   - detections: Array of detection results
    /// - Returns: Annotated image with bounding boxes, or nil if failed
    public func annotateImage(_ image: UIImage, with detections: [DetectionResult]) -> UIImage? {
        return ObjectDetectionModelHandler.shared.annotateImage(image, with: detections)
    }
    
    /// Generate JSON string from detections
    ///
    /// Converts detection results to a JSON string for storage, transmission, or logging.
    /// The JSON includes all detection properties: label, confidence, bounding box, and area.
    ///
    /// ## Parameters
    ///
    /// - `detections`: Array of `DetectionResult` objects (required)
    ///
    /// ## Returns
    ///
    /// `String` - JSON string representation of detections
    ///
    /// ## JSON Format
    ///
    /// ```json
    /// [
    ///   {
    ///     "label": "chair",
    ///     "confidence": 0.85,
    ///     "boundingBox": {
    ///       "x": 0.2,
    ///       "y": 0.3,
    ///       "width": 0.15,
    ///       "height": 0.2
    ///     },
    ///     "areaPercentage": 0.03
    ///   }
    /// ]
    /// ```
    ///
    /// ## Example
    ///
    /// ```swift
    /// sdk.detectObjects(image) { detections, _ in
    ///     guard let detections = detections else { return }
    ///
    ///     let jsonString = sdk.generateJSON(from: detections)
    ///     print(jsonString)
    ///
    ///     // Save to file
    ///     try? jsonString.write(to: fileURL, atomically: true, encoding: .utf8)
    /// }
    /// ```
    ///
    /// - Parameter detections: Array of detection results
    /// - Returns: JSON string representation
    public func generateJSON(from detections: [DetectionResult]) -> String {
        return ObjectDetectionModelHandler.shared.generateJSON(from: detections)
    }
    
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
    
    /// Tag images using the Tagger API
    ///
    /// This method sends images to the Tagger API endpoint to get room category classifications
    /// and best picks for each room type. Images are sent with their identifiers for mapping
    /// results back to the original images.
    ///
    /// ## Parameters
    ///
    /// - `imagesWithIDs: [ImageWithID]` - Array of images with their identifiers (required, max 15)
    ///   - `image: UIImage` - The image to tag
    ///   - `identifier: String` - PHAsset localIdentifier or custom ID for mapping results
    /// - `completion: @escaping (Result<TaggerCompleteResult, Error>) -> Void` - Completion handler (required)
    ///
    /// ## Returns
    ///
    /// `Void` - Results are provided via the completion handler
    ///
    /// ## TaggerCompleteResult Properties
    ///
    /// - `meta: TaggerMeta` - API metadata (total images, latency, timestamp)
    /// - `bestPicks: [BestPickResult]` - Best image for each room category (living_room, dining, bathroom, kitchen, bedroom)
    /// - `results: [TaggerResult]` - All image results with category, score, and status
    ///
    /// ## Example
    ///
    /// ```swift
    /// let imagesWithIDs: [ImageWithID] = [
    ///     ImageWithID(image: image1, identifier: "localIdentifier1"),
    ///     ImageWithID(image: image2, identifier: "localIdentifier2")
    /// ]
    ///
    /// sdk.tagImages(imagesWithIDs) { result in
    ///     switch result {
    ///     case .success(let taggerResult):
    ///         print("Processed \(taggerResult.meta.totalImages) images")
    ///         print("Best picks: \(taggerResult.bestPicks.count)")
    ///         for bestPick in taggerResult.bestPicks {
    ///             print("\(bestPick.category): Score \(bestPick.bestPick.score)")
    ///         }
    ///     case .failure(let error):
    ///         print("Error: \(error.localizedDescription)")
    ///     }
    /// }
    /// ```
    ///
    /// ## Thread Safety
    ///
    /// This method is thread-safe. The completion handler is called on a background queue.
    ///
    /// - Parameters:
    ///   - imagesWithIDs: Array of images with identifiers (max 15)
    ///   - completion: Completion handler with result
    public func tagImages(_ imagesWithIDs: [ImageWithID], completion: @escaping (Result<TaggerCompleteResult, Error>) -> Void) {
        TaggerAPIHandler.shared.tagImages(imagesWithIDs, completion: completion)
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
    public func generateRooms(
        from taggerResult: TaggerCompleteResult,
        objectImages: [String: UIImage]? = nil,
        objectUrls: [String: [String]]? = nil,
        completion: @escaping (Result<RoomGenerationCompleteResult, Error>) -> Void
    ) {
        TaggerAPIHandler.shared.generateRooms(from: taggerResult, objectImages: objectImages, objectUrls: objectUrls, completion: completion)
    }
    
    /// Personalizes categories by generating room images
    /// - Parameters:
    ///   - taggerResult: The tagger API result containing categorized images
    ///   - categoryProductUrls: Dictionary mapping category IDs to arrays of product image URLs [categoryId: [url1, url2, ...]]
    ///   - categoryRoomTypeMap: Dictionary mapping category IDs to room types [categoryId: "bedroom"|"living_room"|"dining_room"]
    ///   - completion: Completion handler with dictionary of categoryId -> generated UIImage (app should upload these to get URLs)
    public func personalizeCategories(
        from taggerResult: TaggerCompleteResult,
        categoryProductUrls: [Int: [String]],
        categoryRoomTypeMap: [Int: String],
        completion: @escaping (Result<[Int: UIImage], Error>) -> Void
    ) {
        TaggerAPIHandler.shared.personalizeCategories(
            from: taggerResult,
            categoryProductUrls: categoryProductUrls,
            categoryRoomTypeMap: categoryRoomTypeMap,
            completion: completion
        )
    }
    
    /// Personalizes products with full tracking, caching, and result object
    /// - Parameters:
    ///   - taggerResult: The tagger API result containing categorized images
    ///   - productUrls: Dictionary mapping product IDs to product image URLs [productId: url]
    ///   - productCategoryMap: Dictionary mapping product IDs to category IDs [productId: categoryId]
    ///   - categoryRoomTypeMap: Dictionary mapping category IDs to room types [categoryId: "bedroom"|"living_room"|"dining_room"]
    ///   - clearCache: Whether to clear cache before generating (default: true)
    ///   - minimumProductCount: Minimum number of products required for personalization (default: 3)
    ///   - completion: Completion handler with PersonalizationResult containing all mappings and cached images
    public func personalizeProducts(
        from taggerResult: TaggerCompleteResult,
        productUrls: [Int: String],
        productCategoryMap: [Int: Int],
        categoryRoomTypeMap: [Int: String],
        clearCache: Bool = true,
        minimumProductCount: Int = 3,
        completion: @escaping (Result<PersonalizationResult, Error>) -> Void
    ) {
        TaggerAPIHandler.shared.personalizeProducts(
            from: taggerResult,
            productUrls: productUrls,
            productCategoryMap: productCategoryMap,
            categoryRoomTypeMap: categoryRoomTypeMap,
            clearCache: clearCache,
            minimumProductCount: minimumProductCount,
            completion: completion
        )
    }
}

