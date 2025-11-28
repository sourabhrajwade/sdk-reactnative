# AIModelOnDeviceSDK Setup Guide

## Project Structure

```
AIModelOnDeviceSDK/
├── Package.swift                    # Swift Package Manager configuration
├── README.md                        # SDK documentation
├── SETUP.md                         # This file
└── AIModelOnDeviceSDK/
    ├── AIModelOnDeviceSDK.swift     # Main SDK entry point
    ├── Models/                      # Data models
    │   ├── YOLOModel.swift
    │   ├── DetectionResult.swift
    │   └── VerificationResult.swift
    ├── Handlers/                    # Core functionality handlers
    │   ├── ObjectDetectionModelHandler.swift
    │   ├── InteriorVerificationHandler.swift
    │   └── FaceNetModelHandler.swift
    └── Resources/                   # Model files
        ├── models/                  # YOLO models
        │   ├── yolo11n.mlpackage
        │   ├── yolo11s.mlpackage
        │   ├── yolo11m.mlpackage
        │   ├── yolo11l.mlpackage
        │   ├── yolo11x.mlpackage
        │   ├── YOLOv3.mlmodel
        │   └── YOLOv3Tiny.mlmodel
        └── facenet.tflite           # FaceNet model
```

## Installation Options

### Option 1: Swift Package Manager (Recommended)

1. In Xcode, go to **File → Add Packages...**
2. Enter the local path or repository URL
3. Select the package and add it to your target

Or add to your `Package.swift`:

```swift
dependencies: [
    .package(path: "../AIModelOnDeviceSDK")
]
```

### Option 2: Manual Framework Integration

1. Open Xcode
2. Create a new Framework target (if not already created)
3. Add all Swift files from `AIModelOnDeviceSDK/` to the target
4. Add `Resources/` folder to the target as a "Resource Bundle"
5. Add TensorFlowLiteSwift dependency

## Creating Xcode Project (Optional)

If you want to create an Xcode project for the SDK:

1. Open Terminal in the SDK directory
2. Run: `swift package generate-xcodeproj` (if using older Swift versions)
3. Or open the Package.swift directly in Xcode (Xcode 11+)

## Dependencies

- **No External Dependencies**: SDK is self-contained
  - All models are included in the SDK bundle
  - No additional package managers required

## Model Files

All model files are included in the `Resources/` folder:

- **YOLO Models**: Located in `Resources/models/`
  - YOLO11 variants (nano, small, medium, large, xlarge)
  - YOLOv3 and YOLOv3 Tiny
- **FaceNet Model**: `Resources/facenet.tflite`

Make sure these files are included in your app bundle when distributing.

## Usage Example

```swift
import AIModelOnDeviceSDK
import UIKit

// Initialize SDK
let sdk = AIModelOnDeviceSDK.shared

// Verify interior image
let image = UIImage(named: "room.jpg")!
sdk.verifyInteriorImage(image, using: .yolo11n) { result in
    print("Valid: \(result.isValid)")
    print("Score: \(result.score)")
    print("Latency: \(result.totalLatency)ms")
}
```

## Troubleshooting

### Models Not Found

If you get errors about models not being found:

1. Ensure `Resources/` folder is added to the target
2. Check that models are included in "Copy Bundle Resources"
3. Verify bundle path in code matches your setup

### Model Loading Issues

If models fail to load:

1. Check that model files are in the bundle
2. Verify bundle path in code matches your setup
3. Review console logs for specific error messages

## Building the SDK

### Using Swift Package Manager

```bash
swift build
```

### Using Xcode

1. Open Package.swift in Xcode
2. Select the scheme
3. Build (Cmd+B)

## Testing

Create a test app that imports the SDK and verifies:

1. Models load correctly
2. Object detection works
3. Interior verification works
4. Face embedding works

## Next Steps

1. Review the README.md for API documentation
2. Check example usage in the README
3. Integrate into your app
4. Test with your images
