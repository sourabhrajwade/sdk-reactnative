# AIModelOnDeviceSDK

A comprehensive iOS SDK for on-device AI model inference, providing interior image verification, object detection, and product personalization capabilities using YOLO models and cloud APIs.

## 📋 Table of Contents

- [Features](#-features)
- [Requirements](#-requirements)
- [Installation](#-installation)
- [Quick Start](#-quick-start)
- [Core Features](#-core-features)
  - [Interior Image Verification](#interior-image-verification)
  - [Object Detection](#object-detection)
  - [Image Filtering](#image-filtering)
- [Personalization Features](#-personalization-features)
  - [Tagger API](#tagger-api)
  - [Room Generation](#room-generation)
  - [Product Personalization](#product-personalization)
- [API Reference](#-api-reference)
- [Data Models](#-data-models)
- [Usage Examples](#-usage-examples)
- [Best Practices](#-best-practices)
- [Performance](#-performance)
- [Troubleshooting](#-troubleshooting)

## ✨ Features

### Core AI Features

- **Interior Image Verification**: Verify if images are valid interior photos with quality scoring
- **Object Detection**: Detect objects in images using YOLO models
- **Batch Processing**: Process multiple images efficiently with parallel execution
- **Image Filtering**: Filter and rank images by quality score, returning top results
- **Model Caching**: Automatic model caching for improved performance
- **Model Auto-Download**: Automatically downloads YOLOv3 model from Apple's CDN if not found locally

### Personalization Features

- **Tagger API Integration**: Classify room images and get best picks for each room type
- **Room Generation**: Generate personalized room images by combining room photos with product images
- **Product Personalization**: Full pipeline for personalizing products with room context
- **Request Tracking**: Track all personalization requests and responses
- **Image Caching**: Persistent caching of generated images

## 📱 Requirements

- **iOS**: 13.0 or later
- **Xcode**: 14.0 or later
- **Swift**: 5.9 or later
- **No External Dependencies**: SDK is self-contained
- **Internet Connection**: Required for Tagger API and room generation API calls

## 📦 Installation

### Swift Package Manager (Recommended)

#### Option 1: Add via Xcode

1. In Xcode, go to **File → Add Packages...**
2. Enter the repository URL: `https://github.com/sourabhrajwade/sdk-reactnative`
3. Select the branch: `main` (or specific version)
4. Click **"Add Package"**
5. Select your target and click **"Add Package"**

#### Option 2: Add via Package.swift

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/sourabhrajwade/sdk-reactnative.git", branch: "main")
]
```

#### Option 3: Add via Xcode Project Settings

1. Select your project in Xcode
2. Go to **Package Dependencies** tab
3. Click **+** button
4. Enter: `https://github.com/sourabhrajwade/sdk-reactnative`
5. Select branch: `main`
6. Click **Add Package**

### Import the SDK

```swift
import AIModelOnDeviceSDK
import UIKit
```

## 🚀 Quick Start

### 1. Initialize the SDK

```swift
let sdk = AIModelOnDeviceSDK.shared
```

### 2. Verify an Interior Image

```swift
let image = UIImage(named: "room.jpg")!

sdk.verifyInteriorImage(image, using: .yolov3) { result in
    if result.isValid {
        print("✅ Valid interior! Score: \(result.score)")
    } else {
        print("❌ Invalid image")
    }
}
```

### 3. Detect Objects

```swift
sdk.detectObjects(image, using: .yolov3) { detections, latency in
    guard let detections = detections else { return }

    print("Found \(detections.count) objects in \(latency ?? 0)ms")
    for detection in detections {
        print("\(detection.label): \(detection.confidencePercentage)")
    }
}
```

## 🎯 Core Features

### Interior Image Verification

Verify if an image is a valid interior room photo with comprehensive quality scoring.

**Method:**

```swift
public func verifyInteriorImage(
    _ image: UIImage,
    using modelType: YOLOModel = .yolov3,
    completion: @escaping (VerificationResult) -> Void
)
```

**What it does:**

1. Detects objects in the image using YOLO
2. Applies 10 filter checks:
   - Object Detection
   - Object Confidence (> 60%)
   - Room Detection (person or furniture)
   - Person Coverage (≤ 20%)
   - Furniture Coverage (10-70%)
   - Object Spread (distribution)
   - Clutter Filter (≤ 10 objects)
   - Aspect Ratio (0.5-2.0)
   - Color Variance (lighting quality)
   - Composition (center proximity)
3. Calculates quality score (0.0 - 1.0)
4. Returns detailed results

**Example:**

```swift
sdk.verifyInteriorImage(image, using: .yolov3) { result in
    print("Valid: \(result.isValid)")
    print("Score: \(result.score)")
    print("Latency: \(result.totalLatency)ms")

    // Check individual filters
    for filter in result.filterResults {
        print("\(filter.name): \(filter.passed ? "✅" : "❌")")
    }

    // Access detailed score breakdown
    if let breakdown = result.scoreBreakdown {
        print("Furniture Coverage: \(breakdown.furnitureCoverageScore)")
        print("Spread: \(breakdown.spreadScore)")
        print("Composition: \(breakdown.compositionScore)")
        print("Color: \(breakdown.colorScore)")
        print("Final Score: \(breakdown.finalScore)")
    }
}
```

### Object Detection

Detect objects in images using YOLO models.

**Method:**

```swift
public func detectObjects(
    _ image: UIImage,
    using modelType: YOLOModel = .yolov3,
    completion: @escaping ([DetectionResult]?, Double?) -> Void
)
```

**Example:**

```swift
sdk.detectObjects(image, using: .yolov3) { detections, latency in
    guard let detections = detections else {
        print("Detection failed")
        return
    }

    print("Found \(detections.count) objects in \(latency ?? 0)ms")

    for detection in detections {
        print("\(detection.label): \(detection.confidencePercentage)")
        print("Position: x=\(detection.boundingBox.x), y=\(detection.boundingBox.y)")
        print("Size: \(detection.boundingBox.width) x \(detection.boundingBox.height)")
        print("Area: \(detection.areaPercentageString)")
    }
}
```

### Image Filtering

Filter and return top 15 images sorted by highest quality score.

**Method:**

```swift
public func filterResults(
    _ images: [UIImage],
    using modelType: YOLOModel = .yolov3,
    completion: @escaping ([ImageVerificationResult]) -> Void
)
```

**Example:**

```swift
let images: [UIImage] = [...] // Your array of images

sdk.filterResults(images, using: .yolov3) { topResults in
    print("Top \(topResults.count) images by score:")

    for (index, imageResult) in topResults.enumerated() {
        if let score = imageResult.result.scoreBreakdown?.finalScore {
            print("\(index + 1). Score: \(score)")
            print("   Original Index: \(imageResult.index)")
            print("   Valid: \(imageResult.result.isValid)")

            // Use imageResult.image to display
        }
    }
}
```

## 🎨 Personalization Features

### Tagger API

Classify room images and get best picks for each room type.

**Method:**

```swift
public func tagImages(
    _ imagesWithIDs: [ImageWithID],
    completion: @escaping (Result<TaggerCompleteResult, Error>) -> Void
)
```

**Parameters:**

- `imagesWithIDs: [ImageWithID]` - Array of images with identifiers (max 15)
  - `image: UIImage` - The image to tag
  - `identifier: String` - PHAsset localIdentifier or custom ID

**Example:**

```swift
let imagesWithIDs: [ImageWithID] = [
    ImageWithID(image: image1, identifier: "localIdentifier1"),
    ImageWithID(image: image2, identifier: "localIdentifier2")
]

sdk.tagImages(imagesWithIDs) { result in
    switch result {
    case .success(let taggerResult):
        print("Processed \(taggerResult.meta.totalImages) images")
        print("Latency: \(taggerResult.meta.latencySeconds)s")

        // Access best picks for each room type
        for bestPick in taggerResult.bestPicks {
            print("\(bestPick.category): Score \(bestPick.bestPick.score)")
            if let image = bestPick.image {
                // Use the best pick image
            }
        }

        // Access all results
        for result in taggerResult.results {
            print("Image \(result.identifier):")
            print("  Category: \(result.taggerResult.category ?? "none")")
            print("  Score: \(result.taggerResult.score)")
            print("  Status: \(result.taggerResult.status)")
        }

    case .failure(let error):
        print("Error: \(error.localizedDescription)")
    }
}
```

### Room Generation

Generate personalized room images by combining room photos with product images.

**Method:**

```swift
public func generateRooms(
    from taggerResult: TaggerCompleteResult,
    objectImages: [String: UIImage]? = nil,
    objectUrls: [String: [String]]? = nil,
    completion: @escaping (Result<RoomGenerationCompleteResult, Error>) -> Void
)
```

**Parameters:**

- `taggerResult: TaggerCompleteResult` - Result from tagger API
- `objectImages: [String: UIImage]?` - Dictionary mapping object labels to images (deprecated, use `objectUrls`)
  - Keys: "bed", "sofa", "table"
- `objectUrls: [String: [String]]?` - Dictionary mapping room types to arrays of product image URLs (preferred)
  - Keys: "bedroom", "living_room", "dining_room"
  - Values: Arrays of product image URLs

**Example:**

```swift
// Using object URLs (recommended)
let objectUrls: [String: [String]] = [
    "bedroom": ["https://example.com/bed1.jpg", "https://example.com/bed2.jpg"],
    "living_room": ["https://example.com/sofa1.jpg"],
    "dining_room": ["https://example.com/table1.jpg"]
]

sdk.generateRooms(from: taggerResult, objectUrls: objectUrls) { result in
    switch result {
    case .success(let roomResults):
        print("Generated \(roomResults.totalGenerated) room images")

        for roomResult in roomResults.results {
            print("Room Type: \(roomResult.roomType)")
            print("Category: \(roomResult.category)")
            print("Object URL: \(roomResult.objectUrl ?? "none")")

            // Use roomResult.generatedImage
            // Use roomResult.roomImage for original room
        }

    case .failure(let error):
        print("Error: \(error.localizedDescription)")
    }
}
```

### Product Personalization

Full pipeline for personalizing products with room context, including request tracking and image caching.

**Method:**

```swift
public func personalizeProducts(
    from taggerResult: TaggerCompleteResult,
    productUrls: [Int: String],
    productCategoryMap: [Int: Int],
    categoryRoomTypeMap: [Int: String],
    clearCache: Bool = true,
    completion: @escaping (Result<PersonalizationResult, Error>) -> Void
)
```

**Parameters:**

- `taggerResult: TaggerCompleteResult` - Result from tagger API
- `productUrls: [Int: String]` - Dictionary mapping product IDs to product image URLs
- `productCategoryMap: [Int: Int]` - Dictionary mapping product IDs to category IDs
- `categoryRoomTypeMap: [Int: String]` - Dictionary mapping category IDs to room types ("bedroom", "living_room", "dining_room")
- `clearCache: Bool` - Whether to clear cache before generating (default: true)
- `completion: @escaping (Result<PersonalizationResult, Error>) -> Void` - Completion handler

**Example:**

```swift
// Prepare your data
let productUrls: [Int: String] = [
    1: "https://example.com/product1.jpg",
    2: "https://example.com/product2.jpg"
]

let productCategoryMap: [Int: Int] = [
    1: 10, // Product 1 belongs to category 10
    2: 20  // Product 2 belongs to category 20
]

let categoryRoomTypeMap: [Int: String] = [
    10: "bedroom",    // Category 10 is bedroom
    20: "living_room" // Category 20 is living room
]

// Call personalization
sdk.personalizeProducts(
    from: taggerResult,
    productUrls: productUrls,
    productCategoryMap: productCategoryMap,
    categoryRoomTypeMap: categoryRoomTypeMap,
    clearCache: true
) { result in
    switch result {
    case .success(let personalizationResult):
        print("✅ Personalization complete!")
        print("Products: \(personalizationResult.productImageMap.count)")
        print("Categories: \(personalizationResult.categoryImageMap.count)")
        print("Requests tracked: \(personalizationResult.requestMap.count)")

        // Access product images (base64 data URLs)
        for (productId, imageUrl) in personalizationResult.productImageMap {
            print("Product \(productId): \(imageUrl)")
            // Upload imageUrl to your server or use directly
        }

        // Access category images
        for (categoryId, imageUrl) in personalizationResult.categoryImageMap {
            print("Category \(categoryId): \(imageUrl)")
        }

        // Access cached UIImage objects
        for (key, image) in personalizationResult.cachedImages {
            print("Cached image: \(key)")
            // Use image directly in UI
        }

        // Access request tracking
        let allRequests = personalizationResult.requestMap.getAllRequests()
        for request in allRequests {
            print("Request \(request.id):")
            print("  Product: \(request.productId ?? -1)")
            print("  Category: \(request.categoryId ?? -1)")
            print("  Room Type: \(request.roomType)")
            print("  Object URL: \(request.objectUrl)")
            print("  Generated URL: \(request.generatedImageUrl ?? "none")")
        }

    case .failure(let error):
        print("❌ Error: \(error.localizedDescription)")
    }
}
```

**PersonalizationResult Properties:**

- `productImageMap: [Int: String]` - Map of product ID to generated image URL (base64 data URL)
- `categoryImageMap: [Int: String]` - Map of category ID to generated image URL (base64 data URL)
- `requestMap: PersonalizationRequestMap` - Complete request tracking map
- `cachedImages: [String: UIImage]` - All generated images cached by the SDK

## 📚 API Reference

### AIModelOnDeviceSDK

Main SDK class - singleton pattern.

#### Shared Instance

```swift
public static let shared: AIModelOnDeviceSDK
```

#### Methods

| Method                                                                                                | Parameters                                                                                                                       | Returns    | Description                          |
| ----------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------- | ---------- | ------------------------------------ |
| `verifyInteriorImage(_:using:completion:)`                                                            | `UIImage`, `YOLOModel?`, `(VerificationResult) -> Void`                                                                          | `Void`     | Verify interior image                |
| `filterResults(_:using:completion:)`                                                                  | `[UIImage]`, `YOLOModel?`, `([ImageVerificationResult]) -> Void`                                                                 | `Void`     | Filter top 15 images by score        |
| `detectObjects(_:using:completion:)`                                                                  | `UIImage`, `YOLOModel?`, `([DetectionResult]?, Double?) -> Void`                                                                 | `Void`     | Detect objects                       |
| `annotateImage(_:with:)`                                                                              | `UIImage`, `[DetectionResult]`                                                                                                   | `UIImage?` | Annotate image with bounding boxes   |
| `generateJSON(from:)`                                                                                 | `[DetectionResult]`                                                                                                              | `String`   | Generate JSON from detections        |
| `clearCache()`                                                                                        | None                                                                                                                             | `Void`     | Clear model cache                    |
| `tagImages(_:completion:)`                                                                            | `[ImageWithID]`, `(Result<TaggerCompleteResult, Error>) -> Void`                                                                 | `Void`     | Tag images with Tagger API           |
| `generateRooms(from:objectImages:objectUrls:completion:)`                                             | `TaggerCompleteResult`, `[String: UIImage]?`, `[String: [String]]?`, `(Result<RoomGenerationCompleteResult, Error>) -> Void`     | `Void`     | Generate room images                 |
| `personalizeCategories(from:categoryProductUrls:categoryRoomTypeMap:completion:)`                     | `TaggerCompleteResult`, `[Int: [String]]`, `[Int: String]`, `(Result<[Int: UIImage], Error>) -> Void`                            | `Void`     | Personalize categories               |
| `personalizeProducts(from:productUrls:productCategoryMap:categoryRoomTypeMap:clearCache:completion:)` | `TaggerCompleteResult`, `[Int: String]`, `[Int: Int]`, `[Int: String]`, `Bool`, `(Result<PersonalizationResult, Error>) -> Void` | `Void`     | Personalize products (full pipeline) |

## 📊 Data Models

### YOLOModel

Enum representing available YOLO model types.

```swift
public enum YOLOModel: String, CaseIterable {
    case yolov3 = "yolov3"
}
```

**Properties:**

- `displayName: String` - Human-readable name
- `modelDescription: String` - Description of the model

### VerificationResult

Result structure from interior image verification.

```swift
public struct VerificationResult {
    public var isValid: Bool
    public var score: Double
    public var detections: [DetectionResult]
    public var filterResults: [FilterResult]
    public var scoreBreakdown: ScoreBreakdown?
    public var totalLatency: Double
    public var status: String
}
```

### DetectionResult

Object detection result.

```swift
public struct DetectionResult: Codable, Identifiable {
    public let id: UUID
    public let label: String
    public let confidence: Float
    public let boundingBox: BoundingBox
    public let areaPercentage: Float
    public var confidencePercentage: String
    public var areaPercentageString: String
}
```

### TaggerCompleteResult

Complete result from Tagger API.

```swift
public struct TaggerCompleteResult {
    public let meta: TaggerMeta
    public let bestPicks: [BestPickResult]
    public let results: [TaggerResult]
}
```

### PersonalizationResult

Complete result from product personalization.

```swift
public struct PersonalizationResult {
    public let productImageMap: [Int: String]
    public let categoryImageMap: [Int: String]
    public let requestMap: PersonalizationRequestMap
    public let cachedImages: [String: UIImage]
}
```

### RoomGenerationResult

Result from room generation.

```swift
public struct RoomGenerationResult: Identifiable {
    public let id: UUID
    public let category: String
    public let roomImage: UIImage
    public let objectImage: UIImage?
    public let objectUrl: String?
    public let generatedImage: UIImage
    public let roomType: String
}
```

## 💡 Usage Examples

### Example 1: Complete Personalization Pipeline

```swift
import AIModelOnDeviceSDK
import UIKit

class PersonalizationService {
    let sdk = AIModelOnDeviceSDK.shared

    func runPersonalizationPipeline(images: [UIImage]) {
        // Step 1: Tag images
        let imagesWithIDs = images.enumerated().map { index, image in
            ImageWithID(image: image, identifier: "image_\(index)")
        }

        sdk.tagImages(imagesWithIDs) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let taggerResult):
                // Step 2: Personalize products
                self.personalizeProducts(from: taggerResult)

            case .failure(let error):
                print("Tagger API error: \(error.localizedDescription)")
            }
        }
    }

    func personalizeProducts(from taggerResult: TaggerCompleteResult) {
        // Prepare your product data
        let productUrls: [Int: String] = [
            1: "https://example.com/product1.jpg",
            2: "https://example.com/product2.jpg"
        ]

        let productCategoryMap: [Int: Int] = [
            1: 10,
            2: 20
        ]

        let categoryRoomTypeMap: [Int: String] = [
            10: "bedroom",
            20: "living_room"
        ]

        // Step 3: Personalize
        sdk.personalizeProducts(
            from: taggerResult,
            productUrls: productUrls,
            productCategoryMap: productCategoryMap,
            categoryRoomTypeMap: categoryRoomTypeMap,
            clearCache: true
        ) { result in
            switch result {
            case .success(let personalizationResult):
                // Step 4: Use results
                self.handlePersonalizationResult(personalizationResult)

            case .failure(let error):
                print("Personalization error: \(error.localizedDescription)")
            }
        }
    }

    func handlePersonalizationResult(_ result: PersonalizationResult) {
        // Upload images to your server
        for (productId, imageUrl) in result.productImageMap {
            uploadImageToServer(productId: productId, imageUrl: imageUrl)
        }

        // Or use cached images directly
        for (key, image) in result.cachedImages {
            displayImage(image, forKey: key)
        }
    }
}
```

### Example 2: SwiftUI Integration

```swift
import SwiftUI
import AIModelOnDeviceSDK

struct PersonalizationView: View {
    @State private var images: [UIImage] = []
    @State private var result: PersonalizationResult?
    @State private var isProcessing = false

    var body: some View {
        VStack {
            if isProcessing {
                ProgressView("Processing...")
            } else if let result = result {
                Text("✅ Personalization Complete!")
                Text("Products: \(result.productImageMap.count)")
                Text("Categories: \(result.categoryImageMap.count)")

                // Display cached images
                ScrollView {
                    ForEach(Array(result.cachedImages.keys), id: \.self) { key in
                        if let image = result.cachedImages[key] {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 200)
                        }
                    }
                }
            } else {
                Button("Start Personalization") {
                    startPersonalization()
                }
            }
        }
    }

    func startPersonalization() {
        isProcessing = true
    let sdk = AIModelOnDeviceSDK.shared

        // Tag images first
        let imagesWithIDs = images.enumerated().map { index, image in
            ImageWithID(image: image, identifier: "\(index)")
        }

        sdk.tagImages(imagesWithIDs) { result in
            switch result {
            case .success(let taggerResult):
                // Personalize
                sdk.personalizeProducts(
                    from: taggerResult,
                    productUrls: [:], // Your product URLs
                    productCategoryMap: [:], // Your mapping
                    categoryRoomTypeMap: [:] // Your mapping
                ) { personalizationResult in
                    DispatchQueue.main.async {
                        self.result = try? personalizationResult.get()
                        self.isProcessing = false
                    }
                }

            case .failure(let error):
                print("Error: \(error.localizedDescription)")
                isProcessing = false
            }
        }
    }
}
```

### Example 3: Error Handling

```swift
func personalizeWithErrorHandling() {
    let sdk = AIModelOnDeviceSDK.shared

    sdk.personalizeProducts(
        from: taggerResult,
        productUrls: productUrls,
        productCategoryMap: productCategoryMap,
        categoryRoomTypeMap: categoryRoomTypeMap
    ) { result in
        switch result {
        case .success(let personalizationResult):
            // Validate results
            guard !personalizationResult.productImageMap.isEmpty else {
                print("⚠️ No products personalized")
                return
            }

            // Check for failed requests
            let allRequests = personalizationResult.requestMap.getAllRequests()
            let failedRequests = allRequests.filter { $0.generatedImageUrl == nil }

            if !failedRequests.isEmpty {
                print("⚠️ \(failedRequests.count) requests failed")
                for request in failedRequests {
                    print("  - Request \(request.id) failed")
                }
            }

            // Success
            print("✅ Successfully personalized \(personalizationResult.productImageMap.count) products")

        case .failure(let error):
            if let taggerError = error as? TaggerAPIError {
                switch taggerError {
                case .emptyImages:
                    print("❌ No images provided")
                case .imageConversionFailed:
                    print("❌ Failed to convert image")
                case .invalidURL:
                    print("❌ Invalid API URL")
                case .timeout:
                    print("❌ Request timed out")
                case .httpError(let statusCode):
                    print("❌ HTTP error: \(statusCode)")
                default:
                    print("❌ Error: \(taggerError.localizedDescription)")
                }
            } else {
                print("❌ Unknown error: \(error.localizedDescription)")
            }
        }
    }
}
```

## 🎯 Best Practices

### 1. Model Selection

- Use `.yolov3` for balanced performance and accuracy
- The model is automatically downloaded from Apple's CDN if not found locally

### 2. Image Processing

- Resize large images before processing to improve performance
- Process images in batches for better throughput
- Clear cache when switching between many models

### 3. Personalization

- Always clear cache before starting a new personalization run (`clearCache: true`)
- Use `objectUrls` instead of `objectImages` for better performance
- Track requests using `PersonalizationRequestMap` for debugging
- Upload generated images to your server for persistence

### 4. Error Handling

- Always handle both success and failure cases
- Check for empty results before processing
- Log errors for debugging
- Provide user feedback for long-running operations

### 5. Memory Management

- Release images after processing when possible
- Use `clearCache()` when memory is constrained
- Process images in smaller batches for large datasets

### 6. Thread Safety

- All SDK methods are thread-safe
- Completion handlers are called on the same thread/queue as the method call
- Always dispatch UI updates to the main queue

## ⚡ Performance

### Typical Processing Times

| Operation                 | Time (ms)      | Notes                                       |
| ------------------------- | -------------- | ------------------------------------------- |
| Object Detection (YOLOv3) | 100-180        | Varies by device and image size             |
| Interior Verification     | +50-100        | Includes detection time                     |
| Tagger API                | 2000-5000      | Network dependent                           |
| Room Generation           | 5000-15000     | Network dependent, per image                |
| Product Personalization   | 5000-15000 × N | N = number of products, parallel processing |

### Optimization Tips

1. **Use appropriate model**: YOLOv3 provides good balance
2. **Resize images**: Process smaller images for faster inference
3. **Batch processing**: Process multiple images in parallel
4. **Cache models**: Models are automatically cached after first load
5. **Network optimization**: Use CDN for product images, handle timeouts gracefully

## 🔧 Troubleshooting

### Models Not Found

**Error:** `❌ FAILED: Could not load YOLO model`

**Solutions:**

1. The SDK will automatically download YOLOv3 from Apple's CDN if not found locally
2. Check internet connection for first-time download
3. Check console logs for download progress
4. Model is cached after first download

### Slow Performance

**Issue:** Processing is too slow

**Solutions:**

1. Resize images before processing
2. Process images in smaller batches
3. Check device capabilities (older devices are slower)
4. Use background queues for processing

### Memory Issues

**Issue:** App crashes or memory warnings

**Solutions:**

1. Clear model cache: `sdk.clearCache()`
2. Process images in smaller batches
3. Release images after processing
4. Monitor memory usage with Instruments

### API Errors

**Issue:** Tagger API or room generation fails

**Solutions:**

1. Check internet connection
2. Verify API endpoints are accessible
3. Check request timeout settings
4. Handle errors gracefully with retry logic
5. Check API response status codes

### No Detections

**Issue:** `detections` is `nil` or empty

**Possible Causes:**

1. Image doesn't contain detectable objects
2. Image format issues
3. Model not loaded correctly

**Solutions:**

1. Check console for error messages
2. Try different image
3. Verify image is valid `UIImage`

## 📝 Additional Resources

### Model Information

- **YOLOv3**: Automatically downloaded from Apple's CDN
- **Model Location**: Cached in app's cache directory after download
- **Model Size**: ~248MB (downloaded on first use)

### API Endpoints

The SDK uses the following API endpoints (configured internally):

- Tagger API: `https://hp.gennoctua.com/api/ml/tagger`
- Room Generation API: `https://hp.gennoctua.com/api/gen/generate-room`

### Support

For issues, questions, or contributions:

- Create an issue on GitHub
- Check existing documentation
- Review example code in the repository

## 📄 License

[Add your license information here]

---

**Version:** 1.0.0  
**Last Updated:** December 2024  
**Repository:** https://github.com/sourabhrajwade/sdk-reactnative
