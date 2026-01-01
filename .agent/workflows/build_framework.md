---
description: Build XCFramework for AIModelOnDeviceSDK
---
To build the binary XCFramework for distribution:

1. Open the terminal.
2. Navigate to the project root directory.
// turbo
3. Run the build script:
   ```bash
   ./build_xcframework.sh
   ```
4. Checks the `Build/` directory for `AIModelOnDeviceSDK.xcframework`.

You can verify the framework architecture using:
```bash
lipo -info Build/AIModelOnDeviceSDK.xcframework/ios-arm64/AIModelOnDeviceSDK.framework/AIModelOnDeviceSDK
```
