# Quick Start Guide

Get up and running with AIModelOnDeviceSDK in 5 minutes.

## Step 1: Install the SDK

### Via Xcode

1. Open your Xcode project
2. Go to **File → Add Packages...**
3. Enter: `https://github.com/sourabhrajwade/sdk-reactnative`
4. Select branch: `main`
5. Click **Add Package**
6. Select your target and click **Add Package**

### Import

```swift
import AIModelOnDeviceSDK
import UIKit
```

## Step 2: Initialize

```swift
let sdk = AIModelOnDeviceSDK.shared
```

## Step 3: Use the SDK

### Verify an Interior Image

```swift
let image = UIImage(named: "room.jpg")!

sdk.verifyInteriorImage(image) { result in
    if result.isValid {
        print("✅ Valid! Score: \(result.score)")
    } else {
        print("❌ Invalid image")
    }
}
```

### Detect Objects

```swift
sdk.detectObjects(image) { detections, latency in
    guard let detections = detections else { return }
    
    for detection in detections {
        print("\(detection.label): \(detection.confidencePercentage)")
    }
}
```

### Personalize Products

```swift
// 1. Tag images
let imagesWithIDs = images.map { ImageWithID(image: $0, identifier: UUID().uuidString) }

sdk.tagImages(imagesWithIDs) { result in
    switch result {
    case .success(let taggerResult):
        // 2. Personalize
        sdk.personalizeProducts(
            from: taggerResult,
            productUrls: [1: "https://example.com/product.jpg"],
            productCategoryMap: [1: 10],
            categoryRoomTypeMap: [10: "bedroom"]
        ) { personalizationResult in
            switch personalizationResult {
            case .success(let result):
                print("✅ Personalized \(result.productImageMap.count) products")
            case .failure(let error):
                print("❌ Error: \(error)")
            }
        }
        
    case .failure(let error):
        print("❌ Error: \(error)")
    }
}
```

## Next Steps

- Read the [full documentation](README.md)
- Check out [usage examples](README.md#-usage-examples)
- Review [API reference](README.md#-api-reference)

## Common Issues

**Model not found?** The SDK automatically downloads YOLOv3 from Apple's CDN on first use.

**Slow performance?** Resize images before processing or use smaller batches.

**Memory issues?** Call `sdk.clearCache()` when done processing.

