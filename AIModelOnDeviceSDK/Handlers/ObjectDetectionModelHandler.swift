//
//  ObjectDetectionModelHandler.swift
//  AIModelOnDeviceSDK
//
//  Created on 14/11/25.
//

import Foundation
import UIKit
import Vision
import CoreML

/// Handler for object detection using YOLO models
public class ObjectDetectionModelHandler {
    
    /// Shared instance for singleton pattern
    public static let shared = ObjectDetectionModelHandler()
    
    // Cache for loaded models
    private var modelCache: [YOLOModel: VNCoreMLModel] = [:]
    
    private init() {
        // Private initializer for singleton
    }
    
    // Load CoreML model for the specified YOLO model
    private func loadModel(for modelType: YOLOModel) -> VNCoreMLModel? {
        // Check cache first
        if let cachedModel = modelCache[modelType] {
            print("💾 Using cached YOLO model: \(modelType.rawValue)")
            return cachedModel
        }
        
        print("🔍 Attempting to load YOLO model: \(modelType.rawValue)")
        
        let fileName = modelType.modelFileName
        let subdirectory = modelType.modelSubdirectory
        
        // Get the appropriate bundle (SPM or framework)
        // For Swift Package Manager, Bundle.module is automatically available
        // For frameworks, use Bundle(for:)
        func getResourceBundle() -> Bundle {
            // Try Bundle.module (available in Swift 5.3+ for SPM)
            // This is a compile-time constant when building as a Swift Package
            #if canImport(SwiftUI) && swift(>=5.3)
            // Check if we're in a Swift Package context
            if let modulePath = Bundle.main.path(forResource: "AIModelOnDeviceSDK_AIModelOnDeviceSDK", ofType: "bundle"),
               let moduleBundle = Bundle(path: modulePath) {
                return moduleBundle
            }
            #endif
            
            // Default: use the class bundle (works for both SPM and frameworks)
            return Bundle(for: ObjectDetectionModelHandler.self)
        }
        
        // Helper function to try loading from a specific path
        // Try both .mlmodelc (compiled) and .mlmodel (uncompiled) extensions
        func tryLoadModel(fileName: String, extension: String, subdirectory: String?) -> VNCoreMLModel? {
            let bundle = getResourceBundle()
            
            // Try with subdirectory first
            if let subdir = subdirectory {
                // Method 1: Using Bundle.url with subdirectory parameter
                if let modelURL = bundle.url(forResource: fileName, withExtension: `extension`, subdirectory: subdir) {
                    print("📦 Found model at: \(modelURL.path)")
                    return loadModelFromURL(modelURL, fileName: fileName, extension: `extension`)
                }
                
                // Method 2: Try with "Resources" prefix (SPM bundles resources in Resources/)
                if let modelURL = bundle.url(forResource: fileName, withExtension: `extension`, subdirectory: "Resources/\(subdir)") {
                    print("📦 Found model at (Resources path): \(modelURL.path)")
                    return loadModelFromURL(modelURL, fileName: fileName, extension: `extension`)
                }
                
                // Method 3: Construct path manually using URL components
                if let bundlePath = bundle.resourcePath {
                    // Try direct path
                    let modelsDir = (bundlePath as NSString).appendingPathComponent(subdir)
                    let fullPath = (modelsDir as NSString).appendingPathComponent("\(fileName).\(`extension`)")
                    
                    if FileManager.default.fileExists(atPath: fullPath) {
                        let fileURL = URL(fileURLWithPath: fullPath)
                        print("📦 Found model at manual path: \(fullPath)")
                        return loadModelFromURL(fileURL, fileName: fileName, extension: `extension`)
                    }
                    
                    // Try with Resources prefix
                    let resourcesModelsDir = (bundlePath as NSString).appendingPathComponent("Resources/\(subdir)")
                    let resourcesFullPath = (resourcesModelsDir as NSString).appendingPathComponent("\(fileName).\(`extension`)")
                    
                    if FileManager.default.fileExists(atPath: resourcesFullPath) {
                        let fileURL = URL(fileURLWithPath: resourcesFullPath)
                        print("📦 Found model at Resources path: \(resourcesFullPath)")
                        return loadModelFromURL(fileURL, fileName: fileName, extension: `extension`)
                    }
                    
                    print("⚠️ Model not found at: \(fullPath) or \(resourcesFullPath)")
                }
            }
            
            // Try without subdirectory (root bundle)
            if let modelURL = bundle.url(forResource: fileName, withExtension: `extension`) {
                print("📦 Found model at root: \(modelURL.path)")
                return loadModelFromURL(modelURL, fileName: fileName, extension: `extension`)
            }
            
            return nil
        }
        
        // Helper function to load model from URL
        func loadModelFromURL(_ url: URL, fileName: String, extension: String) -> VNCoreMLModel? {
            do {
                if `extension` == "mlmodelc" {
                    // Pre-compiled model - safe to load on any thread
                    let model = try MLModel(contentsOf: url)
                    let visionModel = try VNCoreMLModel(for: model)
                    modelCache[modelType] = visionModel
                    print("✅ Successfully loaded compiled YOLO model: \(fileName).\(`extension`)")
                    return visionModel
                } else {
                    // Need to compile first - must be done on background thread
                    var compiledURL: URL?
                    var compileError: Error?
                    
                    // Use semaphore to wait for background compilation
                    let semaphore = DispatchSemaphore(value: 0)
                    
                    DispatchQueue.global(qos: .userInitiated).async {
                        do {
                            // MLModel.compileModel should not be called on main thread
                            compiledURL = try MLModel.compileModel(at: url)
                        } catch {
                            compileError = error
                        }
                        semaphore.signal()
                    }
                    
                    // Wait for compilation to complete (with timeout)
                    let timeout = semaphore.wait(timeout: .now() + 60) // 60 second timeout
                    
                    if timeout == .timedOut {
                        print("⚠️ Model compilation timed out: \(url.path)")
                        return nil
                    }
                    
                    if let error = compileError {
                        throw error
                    }
                    
                    guard let compiledURL = compiledURL else {
                        print("⚠️ Failed to compile model: \(url.path)")
                        return nil
                    }
                    
                    // Load the compiled model
                    let model = try MLModel(contentsOf: compiledURL)
                    let visionModel = try VNCoreMLModel(for: model)
                    modelCache[modelType] = visionModel
                    print("✅ Successfully compiled and loaded YOLO: \(fileName).\(`extension`)")
                    return visionModel
                }
            } catch {
                print("⚠️ Failed to load model from \(url.path): \(error.localizedDescription)")
        return nil
    }
}
        
        // Strategy 1: Try .mlmodel (uncompiled - will be compiled automatically)
        // Try this first for YOLOv3 since we have YOLOv3.mlmodel in resources
        if let model = tryLoadModel(fileName: fileName, extension: "mlmodel", subdirectory: subdirectory) {
            return model
        }
        
        // Strategy 2: Try to load pre-compiled model (.mlmodelc)
        if let model = tryLoadModel(fileName: fileName, extension: "mlmodelc", subdirectory: subdirectory) {
            return model
        }
        
        // Strategy 3: Try .mlpackage (for YOLO11 models if any remain)
        if let model = tryLoadModel(fileName: fileName, extension: "mlpackage", subdirectory: subdirectory) {
            return model
        }
        
        // Debug: List available resources in models folder
        let bundle = getResourceBundle()
        print("🔍 Debug: Bundle path: \(bundle.bundlePath)")
        print("🔍 Debug: Resource path: \(bundle.resourcePath ?? "nil")")
        
        if let subdir = subdirectory, let bundlePath = bundle.resourcePath {
            // Try direct path
            let modelsPath = (bundlePath as NSString).appendingPathComponent(subdir)
            print("🔍 Debug: Checking models folder at: \(modelsPath)")
            if let contents = try? FileManager.default.contentsOfDirectory(atPath: modelsPath) {
                print("📋 Files in models folder: \(contents.joined(separator: ", "))")
            } else {
                // Try Resources path
                let resourcesModelsPath = (bundlePath as NSString).appendingPathComponent("Resources/\(subdir)")
                print("🔍 Debug: Checking Resources/models folder at: \(resourcesModelsPath)")
                if let contents = try? FileManager.default.contentsOfDirectory(atPath: resourcesModelsPath) {
                    print("📋 Files in Resources/models folder: \(contents.joined(separator: ", "))")
                } else {
                    print("⚠️ Models folder not found at either location")
                }
            }
        }
        
        // Strategy 4: Download from Apple's CDN if not found locally
        // Support all YOLOv3 variants
        if modelType == .yolov3 || modelType == .yolov3FP16 || modelType == .yolov3Int8LUT {
            print("📥 Model not found locally, attempting to download from Apple's CDN...")
            if let downloadedModel = downloadModelFromAppleCDN(modelType: modelType) {
                return downloadedModel
            }
        }
        
        print("❌ FAILED: Could not load YOLO model \(modelType.rawValue)")
        print("   Looking for: \(fileName).mlmodel in \(subdirectory ?? "root")")
        return nil
    }
    
    /// Download YOLOv3 model from Apple's CDN
    private func downloadModelFromAppleCDN(modelType: YOLOModel) -> VNCoreMLModel? {
        // Apple CDN URLs for YOLOv3 models
        let cdnURLs: [YOLOModel: String] = [
            .yolov3: "https://ml-assets.apple.com/coreml/models/Image/ObjectDetection/YOLOv3/YOLOv3.mlmodel",
            .yolov3FP16: "https://ml-assets.apple.com/coreml/models/Image/ObjectDetection/YOLOv3/YOLOv3FP16.mlmodel",
            .yolov3Int8LUT: "https://ml-assets.apple.com/coreml/models/Image/ObjectDetection/YOLOv3/YOLOv3Int8LUT.mlmodel"
        ]
        
        guard let urlString = cdnURLs[modelType],
              let url = URL(string: urlString) else {
            print("❌ No CDN URL available for model: \(modelType.rawValue)")
            return nil
        }
        
        // Check cache directory first
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let modelsCacheDir = cacheDir.appendingPathComponent("AIModelOnDeviceSDK/Models", isDirectory: true)
        let cachedModelURL = modelsCacheDir.appendingPathComponent("\(modelType.modelFileName).mlmodel")
        
        // Create cache directory if it doesn't exist
        try? FileManager.default.createDirectory(at: modelsCacheDir, withIntermediateDirectories: true, attributes: nil)
        
        // Check if model is already cached
        if FileManager.default.fileExists(atPath: cachedModelURL.path) {
            print("💾 Found cached model at: \(cachedModelURL.path)")
            return loadModelFromURL(cachedModelURL, fileName: modelType.modelFileName, extension: "mlmodel")
        }
        
        // Download the model
        print("⬇️ Downloading \(modelType.rawValue) from Apple CDN...")
        var downloadError: Error?
        var downloadedData: Data?
        let semaphore = DispatchSemaphore(value: 0)
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                downloadError = error
                print("❌ Download failed: \(error.localizedDescription)")
            } else if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200, let data = data {
                downloadedData = data
                print("✅ Downloaded \(modelType.rawValue) (\(data.count / 1024 / 1024)MB)")
            } else {
                downloadError = NSError(domain: "ModelDownload", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
            }
            semaphore.signal()
        }.resume()
        
        // Wait for download (with 5 minute timeout for large files)
        let timeout = semaphore.wait(timeout: .now() + 300)
        
        if timeout == .timedOut {
            print("❌ Download timed out")
            return nil
        }
        
        guard let data = downloadedData, downloadError == nil else {
            print("❌ Failed to download model: \(downloadError?.localizedDescription ?? "Unknown error")")
            return nil
        }
        
        // Save to cache
        do {
            try data.write(to: cachedModelURL)
            print("💾 Saved model to cache: \(cachedModelURL.path)")
        } catch {
            print("⚠️ Failed to save model to cache: \(error.localizedDescription)")
            // Try to load from memory instead
            if let tempURL = createTemporaryFile(data: data, fileName: modelType.modelFileName) {
                return loadModelFromURL(tempURL, fileName: modelType.modelFileName, extension: "mlmodel")
            }
            return nil
        }
        
        // Load from cache
        return loadModelFromURL(cachedModelURL, fileName: modelType.modelFileName, extension: "mlmodel")
    }
    
    /// Create a temporary file from data
    private func createTemporaryFile(data: Data, fileName: String) -> URL? {
        let tempDir = FileManager.default.temporaryDirectory
        let tempURL = tempDir.appendingPathComponent("\(fileName).mlmodel")
        
        do {
            try data.write(to: tempURL)
            return tempURL
        } catch {
            print("❌ Failed to create temporary file: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Detect objects in image using the specified YOLO model
    public func detectObjects(_ image: UIImage, using modelType: YOLOModel, completion: @escaping ([DetectionResult]?, Double?) -> Void) {
        // Load model
        guard let model = loadModel(for: modelType) else {
            completion(nil, nil)
            return
        }
        
        // Convert UIImage to CIImage
        guard let ciImage = CIImage(image: image) else {
            print("❌ Failed to convert UIImage to CIImage")
            completion(nil, nil)
            return
        }
        
        // Measure inference time
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Create object detection request
        let request = VNCoreMLRequest(model: model) { request, error in
            let endTime = CFAbsoluteTimeGetCurrent()
            let latency = (endTime - startTime) * 1000 // Convert to milliseconds
            
            if let error = error {
                print("❌ Detection error: \(error)")
                completion(nil, nil)
                return
            }
            
            // Process results
            guard let results = request.results as? [VNRecognizedObjectObservation] else {
                print("❌ No detection results")
                completion(nil, nil)
                return
            }
            
            // Convert to DetectionResult objects
            let detections = results.compactMap { observation -> DetectionResult? in
                guard let label = observation.labels.first else { return nil }
                
                let box = observation.boundingBox
                let boundingBox = BoundingBox(
                    x: Float(box.origin.x),
                    y: Float(box.origin.y),
                    width: Float(box.width),
                    height: Float(box.height)
                )
                
                return DetectionResult(
                    label: label.identifier,
                    confidence: label.confidence,
                    boundingBox: boundingBox,
                    areaPercentage: boundingBox.area
                )
            }
            
            // Sort by area (largest first)
            let sortedDetections = detections.sorted { $0.areaPercentage > $1.areaPercentage }
            
            print("✅ Detection complete: \(sortedDetections.count) objects, Latency: \(String(format: "%.2f", latency))ms")
            completion(sortedDetections, latency)
        }
        
        // Set image crop and scale option
        request.imageCropAndScaleOption = .scaleFill
        
        // Create request handler
        let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
        
        do {
            try handler.perform([request])
        } catch {
            print("❌ Failed to perform detection: \(error)")
            completion(nil, nil)
        }
    }
    
    /// Generate annotated image with bounding boxes
    public func annotateImage(_ image: UIImage, with detections: [DetectionResult]) -> UIImage? {
        let imageSize = image.size
        let scale = image.scale
        
        UIGraphicsBeginImageContextWithOptions(imageSize, false, scale)
        defer { UIGraphicsEndImageContext() }
        
        // Draw original image
        image.draw(at: .zero)
        
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        
        // Configure drawing
        context.setLineWidth(3.0)
        
        for detection in detections {
            // Convert normalized coordinates to image coordinates
            let box = detection.boundingBox
            
            // Vision uses bottom-left origin, need to flip Y
            let rect = CGRect(
                x: CGFloat(box.x) * imageSize.width,
                y: (1 - CGFloat(box.y) - CGFloat(box.height)) * imageSize.height,
                width: CGFloat(box.width) * imageSize.width,
                height: CGFloat(box.height) * imageSize.height
            )
            
            // Choose color based on confidence
            let color: UIColor
            if detection.confidence > 0.8 {
                color = .green
            } else if detection.confidence > 0.5 {
                color = .yellow
            } else {
                color = .orange
            }
            
            // Draw bounding box
            context.setStrokeColor(color.cgColor)
            context.stroke(rect)
            
            // Draw label background
            let label = "\(detection.label) \(detection.confidencePercentage)"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 16),
                .foregroundColor: UIColor.white
            ]
            
            let labelSize = label.size(withAttributes: attributes)
            let labelRect = CGRect(
                x: rect.origin.x,
                y: rect.origin.y - labelSize.height - 4,
                width: labelSize.width + 8,
                height: labelSize.height + 4
            )
            
            context.setFillColor(color.cgColor)
            context.fill(labelRect)
            
            // Draw label text
            label.draw(
                at: CGPoint(x: labelRect.origin.x + 4, y: labelRect.origin.y + 2),
                withAttributes: attributes
            )
        }
        
        return UIGraphicsGetImageFromCurrentImageContext()
    }
    
    /// Generate JSON string from detections
    public func generateJSON(from detections: [DetectionResult]) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        do {
            let jsonData = try encoder.encode(detections)
            return String(data: jsonData, encoding: .utf8) ?? "{}"
        } catch {
            print("❌ Failed to encode JSON: \(error)")
            return "{}"
        }
    }
    
    /// Clear model cache
    public func clearCache() {
        modelCache.removeAll()
        print("🗑️ YOLO model cache cleared")
    }
}

