# AIModelOnDeviceSDK

A comprehensive iOS SDK for on-device AI model inference, providing interior image verification and object detection capabilities using YOLO models.

## 📋 Table of Contents

- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [API Reference](#api-reference)
- [Data Models](#data-models)
- [Usage Examples](#usage-examples)
- [Performance](#performance)
- [Troubleshooting](#troubleshooting)

## ✨ Features

- **Interior Image Verification**: Verify if images are valid interior photos with quality scoring
- **Object Detection**: Detect objects in images using YOLO models (YOLO11, YOLOv3)
- **Batch Processing**: Process multiple images efficiently with parallel execution
- **Image Filtering**: Filter and rank images by quality score, returning top results
- **Model Caching**: Automatic model caching for improved performance
- **Multiple YOLO Models**: Support for 7 different YOLO model variants
- **Detailed Results**: Comprehensive filter checks and score breakdowns

## 📱 Requirements

- **iOS**: 13.0 or later
- **Xcode**: 14.0 or later
- **Swift**: 5.9 or later
- **No External Dependencies**: SDK is self-contained (TensorFlow removed)

## 📦 Installation

### Method 1: Swift Package Manager (Recommended)

#### Option A: Local Package (Development)

1. In Xcode, go to **File → Add Packages...**
2. Click **"Add Local..."**
3. Navigate to and select the `AIModelOnDeviceSDK` folder
4. Click **"Add Package"**
5. Select your target and click **"Add Package"**

#### Option B: Package.swift

Add to your `Package.swift`:

```swift
dependencies: [
    .package(path: "../AIModelOnDeviceSDK")
]
```

#### Option C: Git Repository (If hosted)

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/AIModelOnDeviceSDK.git", from: "1.0.0")
]
```

### Method 2: Manual Integration

1. Copy the `AIModelOnDeviceSDK` folder to your project
2. Add all Swift files to your Xcode target
3. Ensure `Resources/` folder is added to "Copy Bundle Resources"
4. Import in your Swift files: `import AIModelOnDeviceSDK`

### Method 3: Framework (If building as framework)

1. Build the SDK as a framework
2. Add the `.framework` to your project
3. Link the framework in "General → Frameworks, Libraries, and Embedded Content"
4. Import: `import AIModelOnDeviceSDK`

## 🚀 Quick Start

### 1. Import the SDK

```swift
import AIModelOnDeviceSDK
import UIKit
```

### 2. Initialize the SDK

```swift
let sdk = AIModelOnDeviceSDK.shared
```

### 3. Use the SDK

```swift
// Verify an interior image
let image = UIImage(named: "room.jpg")!

sdk.verifyInteriorImage(image, using: .yolo11n) { result in
    if result.isValid {
        print("✅ Valid interior! Score: \(result.score)")
    } else {
        print("❌ Invalid image")
    }
}
```

## 📚 API Reference

### AIModelOnDeviceSDK

Main SDK class - singleton pattern.

#### Shared Instance

```swift
public static let shared: AIModelOnDeviceSDK
```

Get the shared SDK instance:

```swift
let sdk = AIModelOnDeviceSDK.shared
```

---

### Methods

#### 1. `verifyInteriorImage(_:using:completion:)`

Verify if an image is a valid interior room photo.

**Signature:**

```swift
public func verifyInteriorImage(
    _ image: UIImage,
    using modelType: YOLOModel = .yolo11n,
    completion: @escaping (VerificationResult) -> Void
)
```

**Parameters:**

- `image: UIImage` - The image to verify (required)
- `modelType: YOLOModel` - YOLO model to use (optional, default: `.yolo11n`)
- `completion: @escaping (VerificationResult) -> Void` - Completion handler (required)

**Returns:** `Void` (result via completion handler)

**Requirements:**

- Valid `UIImage` object
- Image should contain interior room content for best results
- Model files must be included in app bundle

**Example:**

```swift
sdk.verifyInteriorImage(image, using: .yolo11n) { result in
    print("Valid: \(result.isValid)")
    print("Score: \(result.score)")
    print("Latency: \(result.totalLatency)ms")

    // Check individual filters
    for filter in result.filterResults {
        print("\(filter.name): \(filter.passed)")
    }
}
```

**What it does:**

1. Detects objects in the image using YOLO
2. Applies 10 filter checks:
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

---

#### 2. `filterResults(_:using:completion:)`

Filter and return top 15 images sorted by highest score from scoreBreakdown.

**Signature:**

```swift
public func filterResults(
    _ images: [UIImage],
    using modelType: YOLOModel = .yolo11n,
    completion: @escaping ([ImageVerificationResult]) -> Void
)
```

**Parameters:**

- `images: [UIImage]` - Array of images to verify and filter (required)
- `modelType: YOLOModel` - YOLO model to use (optional, default: `.yolo11n`)
- `completion: @escaping ([ImageVerificationResult]) -> Void` - Completion handler (required)
  - Returns array of top 15 `ImageVerificationResult` sorted by score (highest first)

**Returns:** `Void` (results via completion handler)

**Requirements:**

- Non-empty array of valid `UIImage` objects
- Model files must be included in app bundle

**Example:**

```swift
let images: [UIImage] = [...] // Your array of images

sdk.filterResults(images, using: .yolo11n) { topResults in
    print("Top \(topResults.count) images by score:")

    for (index, imageResult) in topResults.enumerated() {
        if let score = imageResult.result.scoreBreakdown?.finalScore {
            print("\(index + 1). Score: \(score)")
            print("   Image index: \(imageResult.index)")
            print("   Valid: \(imageResult.result.isValid)")
        }
    }
}
```

**What it does:**

1. Verifies all images concurrently for maximum performance
2. Filters to only include valid images with `scoreBreakdown`
3. Sorts by `scoreBreakdown.finalScore` (highest first)
4. Returns top 15 results
5. Each result includes the original image, full verification result, and original index

**Performance:**

- Processes images in parallel for speed
- Only valid images with scores are included
- Results are sorted automatically
- Completion handler called on main queue

---

#### 3. `detectObjects(_:using:completion:)`

Detect objects in an image using YOLO models.

**Signature:**

```swift
public func detectObjects(
    _ image: UIImage,
    using modelType: YOLOModel = .yolo11n,
    completion: @escaping ([DetectionResult]?, Double?) -> Void
)
```

**Parameters:**

- `image: UIImage` - The image to analyze (required)
- `modelType: YOLOModel` - YOLO model to use (optional, default: `.yolo11n`)
- `completion: @escaping ([DetectionResult]?, Double?) -> Void` - Completion handler (required)
  - First parameter: Array of detections, or `nil` if failed
  - Second parameter: Processing latency in milliseconds, or `nil` if failed

**Returns:** `Void` (results via completion handler)

**Requirements:**

- Valid `UIImage` object
- Model files must be included in app bundle

**Example:**

```swift
sdk.detectObjects(image, using: .yolo11n) { detections, latency in
    guard let detections = detections else {
        print("Detection failed")
        return
    }

    print("Found \(detections.count) objects in \(latency ?? 0)ms")

    for detection in detections {
        print("\(detection.label): \(detection.confidencePercentage)")
        print("Position: \(detection.boundingBox)")
    }
}
```

**What it does:**

1. Loads the specified YOLO model (cached if previously loaded)
2. Runs object detection on the image
3. Returns detected objects with:
   - Label (object name)
   - Confidence score
   - Bounding box coordinates
   - Area percentage

---

#### 4. `annotateImage(_:with:)`

Annotate an image with bounding boxes from detection results.

**Signature:**

```swift
public func annotateImage(
    _ image: UIImage,
    with detections: [DetectionResult]
) -> UIImage?
```

**Parameters:**

- `image: UIImage` - The original image (required)
- `detections: [DetectionResult]` - Array of detection results (required)

**Returns:** `UIImage?` - Annotated image with bounding boxes, or `nil` if failed

**Requirements:**

- Valid `UIImage` object
- Non-empty `detections` array

**Example:**

```swift
sdk.detectObjects(image) { detections, _ in
    guard let detections = detections else { return }

    if let annotated = sdk.annotateImage(image, with: detections) {
        // Display annotated image
        imageView.image = annotated
    }
}
```

**What it does:**

1. Draws bounding boxes on the image
2. Adds labels with confidence scores
3. Color codes by confidence:
   - Green: > 80%
   - Yellow: 50-80%
   - Orange: < 50%

---

#### 5. `generateJSON(from:)`

Generate JSON string representation of detection results.

**Signature:**

```swift
public func generateJSON(from detections: [DetectionResult]) -> String
```

**Parameters:**

- `detections: [DetectionResult]` - Array of detection results (required)

**Returns:** `String` - JSON string representation

**Requirements:**

- Non-empty `detections` array

**Example:**

```swift
sdk.detectObjects(image) { detections, _ in
    guard let detections = detections else { return }

    let jsonString = sdk.generateJSON(from: detections)
    print(jsonString)

    // Save to file
    try? jsonString.write(to: fileURL, atomically: true, encoding: .utf8)
}
```

**Output Format:**

```json
[
  {
    "label": "chair",
    "confidence": 0.85,
    "boundingBox": {
      "x": 0.2,
      "y": 0.3,
      "width": 0.15,
      "height": 0.2
    },
    "areaPercentage": 0.03
  }
]
```

---

#### 6. `clearCache()`

Clear the model cache to free memory.

**Signature:**

```swift
public func clearCache()
```

**Parameters:** None

**Returns:** `Void`

**When to use:**

- When memory is constrained
- When switching between many different models
- Before app termination (optional)

**Example:**

```swift
// Clear cache when done
sdk.clearCache()
```

---

## 📊 Data Models

### YOLOModel

Enum representing available YOLO model types.

```swift
public enum YOLOModel: String, CaseIterable
```

**Available Models:**

- `.yolo11n` - YOLO11 Nano (fastest, smallest)
- `.yolo11s` - YOLO11 Small (fast, good accuracy)
- `.yolo11m` - YOLO11 Medium (balanced)
- `.yolo11l` - YOLO11 Large (high accuracy)
- `.yolo11x` - YOLO11 XLarge (best accuracy, slower)
- `.yolov3` - YOLOv3 (classic model)
- `.yolov3tiny` - YOLOv3 Tiny (fastest YOLOv3)

**Properties:**

- `displayName: String` - Human-readable name
- `modelDescription: String` - Description of the model

**Example:**

```swift
let model: YOLOModel = .yolo11n
print(model.displayName) // "YOLO11 Nano"
print(model.modelDescription) // "Fastest, smallest model"
```

---

### VerificationResult

Result structure from interior image verification.

```swift
public struct VerificationResult
```

**Properties:**

- `isValid: Bool` - Whether image passed all verification checks
- `score: Double` - Quality score (0.0 - 1.0), only valid if `isValid == true`
- `detections: [DetectionResult]` - All detected objects
- `filterResults: [FilterResult]` - Individual filter check results
- `scoreBreakdown: ScoreBreakdown?` - Detailed score breakdown (if valid)
- `totalLatency: Double` - Total processing time in milliseconds
- `status: String` - Human-readable status message

**Example:**

```swift
sdk.verifyInteriorImage(image) { result in
    print(result.status) // "✅ Valid Interior Image" or "❌ Invalid Image"
    print("Score: \(result.score)")
    print("Latency: \(result.totalLatency)ms")

    // Check each filter
    for filter in result.filterResults {
        print("\(filter.name): \(filter.passed ? "✅" : "❌")")
    }
}
```

---

### FilterResult

Individual filter check result.

```swift
public struct FilterResult: Identifiable
```

**Properties:**

- `id: UUID` - Unique identifier
- `name: String` - Filter name (e.g., "Object Confidence")
- `passed: Bool` - Whether filter passed
- `message: String` - Human-readable message
- `value: String` - Filter value/measurement
- `latency: Double` - Processing time for this filter (ms)
- `icon: String` - SF Symbol name for icon
- `color: String` - Color name ("green" or "red")

**Filter Names:**

- "Object Detection"
- "Object Confidence"
- "Room Detection"
- "Person Coverage"
- "Furniture Coverage"
- "Object Spread"
- "Clutter Filter"
- "Aspect Ratio"
- "Color Variance"
- "Composition"

---

### ScoreBreakdown

Detailed score breakdown (only available if image is valid).

```swift
public struct ScoreBreakdown: Codable
```

**Properties:**

- `furnitureCoverageScore: Double` - Furniture coverage score (0.0 - 1.0)
- `spreadScore: Double` - Object spread score (0.0 - 1.0)
- `compositionScore: Double` - Composition score (0.0 - 1.0)
- `colorScore: Double` - Color variance score (0.0 - 1.0)
- `finalScore: Double` - Final weighted score (0.0 - 1.0)

**Weights:**

- `furnitureCoverageWeight: Double` - 0.4 (40%)
- `spreadWeight: Double` - 0.25 (25%)
- `compositionWeight: Double` - 0.25 (25%)
- `colorWeight: Double` - 0.10 (10%)

**Example:**

```swift
if let breakdown = result.scoreBreakdown {
    print("Furniture Coverage: \(breakdown.furnitureCoverageScore)")
    print("Spread: \(breakdown.spreadScore)")
    print("Composition: \(breakdown.compositionScore)")
    print("Color: \(breakdown.colorScore)")
    print("Final: \(breakdown.finalScore)")
}
```

---

### ImageVerificationResult

Result wrapper containing both image and verification result.

```swift
public struct ImageVerificationResult: Identifiable
```

**Properties:**

- `id: UUID` - Unique identifier
- `image: UIImage` - The original image
- `result: VerificationResult` - Full verification result with scoreBreakdown
- `index: Int` - Original index in the input array

**Use Case:**
Returned by `filterResults()` method to provide top-ranked images with their scores.

**Example:**

```swift
sdk.filterResults(images) { topResults in
    for imageResult in topResults {
        // Access the image
        let image = imageResult.image

        // Access the verification result
        let result = imageResult.result

        // Access the score
        if let score = result.scoreBreakdown?.finalScore {
            print("Image \(imageResult.index): Score = \(score)")
        }

        // Access original index
        print("Original position: \(imageResult.index)")
    }
}
```

---

### DetectionResult

Object detection result.

```swift
public struct DetectionResult: Codable, Identifiable
```

**Properties:**

- `id: UUID` - Unique identifier
- `label: String` - Detected object label (e.g., "chair", "person")
- `confidence: Float` - Confidence score (0.0 - 1.0)
- `boundingBox: BoundingBox` - Bounding box coordinates
- `areaPercentage: Float` - Area percentage of image (0.0 - 1.0)
- `confidencePercentage: String` - Formatted confidence (e.g., "85.0%")
- `areaPercentageString: String` - Formatted area (e.g., "3.00%")

**Example:**

```swift
for detection in detections {
    print("\(detection.label): \(detection.confidencePercentage)")
    print("Area: \(detection.areaPercentageString)")
    print("Box: x=\(detection.boundingBox.x), y=\(detection.boundingBox.y)")
}
```

---

### BoundingBox

Bounding box coordinates (normalized 0.0 - 1.0).

```swift
public struct BoundingBox: Codable
```

**Properties:**

- `x: Float` - X coordinate (0.0 = left edge, 1.0 = right edge)
- `y: Float` - Y coordinate (0.0 = top edge, 1.0 = bottom edge)
- `width: Float` - Width (0.0 - 1.0)
- `height: Float` - Height (0.0 - 1.0)
- `normalizedRect: CGRect` - CGRect representation
- `area: Float` - Calculated area (width × height)

**Coordinate System:**

- Origin (0,0) is at top-left
- All values are normalized (0.0 - 1.0)
- Multiply by image size to get pixel coordinates

**Example:**

```swift
let box = detection.boundingBox

// Convert to pixel coordinates
let imageWidth = image.size.width
let imageHeight = image.size.height

let pixelX = CGFloat(box.x) * imageWidth
let pixelY = CGFloat(box.y) * imageHeight
let pixelWidth = CGFloat(box.width) * imageWidth
let pixelHeight = CGFloat(box.height) * imageHeight

let rect = CGRect(x: pixelX, y: pixelY, width: pixelWidth, height: pixelHeight)
```

---

## 💡 Usage Examples

### Example 1: Basic Interior Verification

```swift
import AIModelOnDeviceSDK
import UIKit

class ViewController: UIViewController {
    @IBOutlet weak var imageView: UIImageView!

    func verifyImage() {
        guard let image = imageView.image else { return }

        let sdk = AIModelOnDeviceSDK.shared

        sdk.verifyInteriorImage(image, using: .yolo11n) { result in
            DispatchQueue.main.async {
                if result.isValid {
                    self.showSuccess(score: result.score)
                } else {
                    self.showFailure(reason: result.filterResults.first { !$0.passed }?.message)
                }
            }
        }
    }
}
```

### Example 2: Batch Processing with Progress

```swift
func verifyMultipleImages(_ images: [UIImage]) {
    let sdk = AIModelOnDeviceSDK.shared
    var results: [VerificationResult] = []
    var completed = 0

    let total = images.count

    for (index, image) in images.enumerated() {
        sdk.verifyInteriorImage(image, using: .yolo11n) { result in
            results.append(result)
            completed += 1

            DispatchQueue.main.async {
                self.updateProgress(completed: completed, total: total)

                if completed == total {
                    self.processResults(results)
                }
            }
        }
    }
}
```

### Example 3: Object Detection with Visualization

```swift
func detectAndVisualize(_ image: UIImage) {
    let sdk = AIModelOnDeviceSDK.shared

    sdk.detectObjects(image, using: .yolo11m) { detections, latency in
        guard let detections = detections else { return }

        DispatchQueue.main.async {
            // Annotate image
            if let annotated = sdk.annotateImage(image, with: detections) {
                self.imageView.image = annotated
            }

            // Log results
            print("Detected \(detections.count) objects in \(latency ?? 0)ms")
            for detection in detections {
                print("  - \(detection.label): \(detection.confidencePercentage)")
            }
        }
    }
}
```

### Example 4: Model Comparison

```swift
func compareModels(_ image: UIImage) {
    let sdk = AIModelOnDeviceSDK.shared
    let models: [YOLOModel] = [.yolo11n, .yolo11s, .yolo11m]

    for model in models {
        let startTime = CFAbsoluteTimeGetCurrent()

        sdk.detectObjects(image, using: model) { detections, latency in
            let totalTime = (CFAbsoluteTimeGetCurrent() - startTime) * 1000

            print("\(model.displayName):")
            print("  Detections: \(detections?.count ?? 0)")
            print("  Latency: \(latency ?? 0)ms")
            print("  Total: \(totalTime)ms")
        }
    }
}
```

### Example 5: Error Handling

```swift
func verifyWithErrorHandling(_ image: UIImage) {
    let sdk = AIModelOnDeviceSDK.shared

    sdk.verifyInteriorImage(image, using: .yolo11n) { result in
        // Check if verification actually ran
        guard result.totalLatency > 0 else {
            print("❌ Verification failed - no processing occurred")
            return
        }

        // Check if objects were detected
        if result.detections.isEmpty {
            print("⚠️ No objects detected in image")
        }

        // Check individual filters
        let failedFilters = result.filterResults.filter { !$0.passed }
        if !failedFilters.isEmpty {
            print("❌ Failed filters:")
            for filter in failedFilters {
                print("  - \(filter.name): \(filter.message)")
            }
        }

        // Success case
        if result.isValid {
            print("✅ Image passed all checks!")
            if let breakdown = result.scoreBreakdown {
                print("Score breakdown:")
                print("  Furniture: \(breakdown.furnitureCoverageScore)")
                print("  Spread: \(breakdown.spreadScore)")
                print("  Composition: \(breakdown.compositionScore)")
                print("  Color: \(breakdown.colorScore)")
            }
        }
    }
}
```

### Example 6: Filter Top Images by Score

```swift
func filterTopImages(_ images: [UIImage]) {
    let sdk = AIModelOnDeviceSDK.shared

    sdk.filterResults(images, using: .yolo11n) { topResults in
        DispatchQueue.main.async {
            print("Found \(topResults.count) top images")

            // Display top images
            for (index, imageResult) in topResults.enumerated() {
                if let score = imageResult.result.scoreBreakdown?.finalScore {
                    print("Rank \(index + 1):")
                    print("  Score: \(score)")
                    print("  Original Index: \(imageResult.index)")
                    print("  Valid: \(imageResult.result.isValid)")

                    // Use imageResult.image to display
                    // Use imageResult.result for detailed breakdown
                }
            }
        }
    }
}
```

### Example 7: SwiftUI Integration

```swift
import SwiftUI
import AIModelOnDeviceSDK

struct VerificationView: View {
    @State private var image: UIImage?
    @State private var result: VerificationResult?
    @State private var isProcessing = false

    var body: some View {
        VStack {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()

                Button("Verify") {
                    verifyImage(image)
                }
                .disabled(isProcessing)

                if let result = result {
                    Text(result.status)
                    Text("Score: \(result.score, specifier: "%.2f")")
                }
            }
        }
    }

    func verifyImage(_ image: UIImage) {
        isProcessing = true
        let sdk = AIModelOnDeviceSDK.shared

        sdk.verifyInteriorImage(image) { result in
            DispatchQueue.main.async {
                self.result = result
                self.isProcessing = false
            }
        }
    }
}
```

---

## ⚡ Performance

### Typical Processing Times

| Operation             | Model       | Time (ms)                    |
| --------------------- | ----------- | ---------------------------- |
| Object Detection      | YOLO11n     | 50-100                       |
| Object Detection      | YOLO11s     | 80-150                       |
| Object Detection      | YOLO11m     | 120-200                      |
| Object Detection      | YOLO11l     | 180-300                      |
| Object Detection      | YOLO11x     | 250-400                      |
| Object Detection      | YOLOv3      | 100-180                      |
| Object Detection      | YOLOv3 Tiny | 40-80                        |
| Interior Verification | Any         | +50-100 (includes detection) |

_Times vary based on device, image size, and number of objects_

### Optimization Tips

1. **Use appropriate model**: Choose smallest model that meets accuracy needs
2. **Resize images**: Process smaller images for faster inference
3. **Batch processing**: Process multiple images in parallel (limit concurrency)
4. **Cache models**: Models are automatically cached after first load
5. **Clear cache**: Free memory when switching between many models

---

## 🔧 Troubleshooting

### Models Not Found

**Error:** `❌ FAILED: Could not load YOLO model`

**Solutions:**

1. Verify models are in `Resources/models/` folder
2. Check models are added to "Copy Bundle Resources" in Xcode
3. Clean build folder (Cmd+Shift+K) and rebuild
4. Check bundle path in console logs

### Slow Performance

**Issue:** Processing is too slow

**Solutions:**

1. Use smaller model (`.yolo11n` instead of `.yolo11x`)
2. Resize images before processing
3. Limit batch concurrency
4. Check device capabilities (older devices are slower)

### Memory Issues

**Issue:** App crashes or memory warnings

**Solutions:**

1. Clear model cache: `sdk.clearCache()`
2. Process images in smaller batches
3. Use smaller models
4. Release images after processing

### No Detections

**Issue:** `detections` is `nil` or empty

**Possible Causes:**

1. Image doesn't contain detectable objects
2. Model not loaded correctly
3. Image format issues

**Solutions:**

1. Check console for error messages
2. Verify model files are in bundle
3. Try different model
4. Test with known good image

---

## 📦 Models Included

The SDK includes the following models in `Resources/models/`:

- **YOLO11 Models** (`.mlpackage`):

  - `yolo11n.mlpackage` - Nano (smallest, fastest)
  - `yolo11s.mlpackage` - Small
  - `yolo11m.mlpackage` - Medium
  - `yolo11l.mlpackage` - Large
  - `yolo11x.mlpackage` - XLarge (largest, most accurate)

- **YOLOv3 Models** (`.mlmodel`):
  - `YOLOv3.mlmodel` - Standard YOLOv3
  - `YOLOv3Tiny.mlmodel` - Tiny variant

**Total Size:** ~580MB (models are large but necessary for accuracy)

---

## 🧵 Thread Safety

All SDK methods are **thread-safe** and can be called from any thread:

```swift
// Safe to call from background thread
DispatchQueue.global().async {
    sdk.verifyInteriorImage(image) { result in
        // Completion handler called on same thread as method call
        DispatchQueue.main.async {
            // Update UI on main thread
        }
    }
}
```

**Note:** Completion handlers are called on the same thread/queue where the method was invoked. Always dispatch UI updates to the main queue.

---

## 📝 Complete Function Reference

### AIModelOnDeviceSDK.shared

| Method                                     | Parameters                                                       | Returns    | Description                   |
| ------------------------------------------ | ---------------------------------------------------------------- | ---------- | ----------------------------- |
| `verifyInteriorImage(_:using:completion:)` | `UIImage`, `YOLOModel?`, `(VerificationResult) -> Void`          | `Void`     | Verify interior image         |
| `filterResults(_:using:completion:)`       | `[UIImage]`, `YOLOModel?`, `([ImageVerificationResult]) -> Void` | `Void`     | Filter top 15 images by score |
| `detectObjects(_:using:completion:)`       | `UIImage`, `YOLOModel?`, `([DetectionResult]?, Double?) -> Void` | `Void`     | Detect objects                |
| `annotateImage(_:with:)`                   | `UIImage`, `[DetectionResult]`                                   | `UIImage?` | Annotate image                |
| `generateJSON(from:)`                      | `[DetectionResult]`                                              | `String`   | Generate JSON                 |
| `clearCache()`                             | None                                                             | `Void`     | Clear model cache             |

---

## 🔍 Verification Filters Explained

The SDK performs 10 filter checks:

1. **Object Detection** - Ensures objects were detected
2. **Object Confidence** - At least one object with >60% confidence
3. **Room Detection** - Contains person or furniture
4. **Person Coverage** - Person area ≤ 20% of image
5. **Furniture Coverage** - Furniture area between 10-70%
6. **Object Spread** - Objects well-distributed (not clumped)
7. **Clutter Filter** - ≤ 10 furniture objects
8. **Aspect Ratio** - Image ratio between 0.5-2.0
9. **Color Variance** - Good lighting and color variety
10. **Composition** - Furniture positioned well in frame

All filters must pass for `isValid == true`.

---

## 📄 License

[Add your license information here]

---

## 🤝 Support

For issues, questions, or contributions:

- [Create an issue](link-to-issues)
- [Documentation](link-to-docs)
- [Examples](link-to-examples)

---

## 🎯 Quick Reference Card

```swift
// Initialize
let sdk = AIModelOnDeviceSDK.shared

// Verify interior
sdk.verifyInteriorImage(image, using: .yolo11n) { result in
    print(result.isValid ? "✅" : "❌")
}

// Filter top images
sdk.filterResults(images) { topResults in
    print("Top \(topResults.count) images")
}

// Detect objects
sdk.detectObjects(image) { detections, latency in
    print("Found \(detections?.count ?? 0) objects")
}

// Annotate
let annotated = sdk.annotateImage(image, with: detections)

// JSON
let json = sdk.generateJSON(from: detections)

// Clear cache
sdk.clearCache()
```

---

**Version:** 1.0.0  
**Last Updated:** November 2024  
**Maintained by:** [Your Name/Team]
