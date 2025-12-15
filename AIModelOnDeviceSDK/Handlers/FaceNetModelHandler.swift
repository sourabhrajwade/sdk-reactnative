//
//  FaceNetModelHandler.swift
//  AIModelOnDeviceSDK
//
//  Created on 10/12/25.
//

import Foundation
import UIKit
import CoreML
import Vision

/// Handler for FaceNet operations using Core ML or Apple Vision
///
/// Priority:
/// 1. Use FaceNet Core ML model (512-d embedding) if available in the app bundle
/// 2. Fallback to Apple Vision's VNGenerateImageFeaturePrintRequest (2048-d),
///    then reduce to 512-d for compatibility
public class FaceNetModelHandler {
    
    public static let shared = FaceNetModelHandler()
    
    /// Lazily loaded Core ML model for FaceNet
    private var faceNetModel: MLModel?
    private var genderNetModel: MLModel?

    private init() {
        loadFaceNetModelIfNeeded()
        loadGenderNetModel()
    }
    
    // MARK: - Public API
    
    /// Extract face embedding (feature vector) from a face image.
    ///
    /// - Parameter faceImage: Face image (full image, not necessarily cropped)
    /// - Returns: `[Float]` of length 512, or `nil` if embedding could not be computed
    public func getEmbedding(from faceImage: UIImage) -> [Float]? {
        // 1. Try FaceNet Core ML model (preferred, 512-d)
//        if let embedding = getEmbeddingWithFaceNet(from: faceImage) {
//            return ensureEmbeddingSize(embedding, targetSize: 512)
//        }
        
        // 2. Fallback to Vision feature print (typically 2048-d)
        if let visionEmbedding = getEmbeddingWithVision(from: faceImage) {
            // Reduce/normalize to 512-d for API compatibility
            return ensureEmbeddingSize(visionEmbedding, targetSize: 512)
        }
        
        return nil
    }
    
    /// Calculate cosine similarity between two embeddings
    /// - Parameters:
    ///   - embedding1: First embedding vector
    ///   - embedding2: Second embedding vector
    /// - Returns: Similarity score (0.0 to 1.0), higher means more similar
    public func calculateSimilarity(embedding1: [Float], embedding2: [Float]) -> Float {
        guard embedding1.count == embedding2.count else {
            print("❌ Embedding size mismatch: \(embedding1.count) vs \(embedding2.count)")
            return 0.0
        }
        
        var dotProduct: Float = 0.0
        var norm1: Float = 0.0
        var norm2: Float = 0.0
        
        for i in 0..<embedding1.count {
            dotProduct += embedding1[i] * embedding2[i]
            norm1 += embedding1[i] * embedding1[i]
            norm2 += embedding2[i] * embedding2[i]
        }
        
        guard norm1 > 0 && norm2 > 0 else {
            return 0.0
        }
        
        let similarity = dotProduct / (sqrt(norm1) * sqrt(norm2))
        
        // Normalize to 0-1 (Cosine similarity is -1 to 1)
        return (similarity + 1.0) / 2.0
    }
    
    private func classifyGenderWithGenderNet(from image: UIImage) -> String? {
        guard let cgImage = image.cgImage else { return nil }

        guard let model = try? VNCoreMLModel(for: GenderNet().model) else {
            return nil
        }

        let request = VNCoreMLRequest(model: model)

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        do {
            try handler.perform([request])
        } catch {
            print("Failed to perform classification: \(error.localizedDescription)")
            return nil
        }

        if let results = request.results as? [VNClassificationObservation] {
            let sortedResults = results.sorted { $0.confidence > $1.confidence }
            if let topResult = sortedResults.first {
                if topResult.identifier == "Male" {
                    return "Men"
                } else if topResult.identifier == "Female" {
                    return "Women"
                }
            }
        }

        return nil
    }

    /// Classify gender from face image.
    ///
    /// Notes:
    /// - This is a best-effort heuristic using Vision's `VNClassifyImageRequest`.
    /// - For production-quality results, you should replace this with a dedicated
    ///   gender classification Core ML model.
    ///
    /// - Parameter faceImage: Cropped face image to classify.
    /// - Returns: "Men" or "Women", or nil if classification fails / is uncertain.
    public func classifyGender(from faceImage: UIImage) -> String? {
        return classifyGenderWithGenderNet(from: faceImage)
    }
    
    // MARK: - Core ML (FaceNet) path
    
    /// Load FaceNet Core ML model if it's present in the app bundle.
    ///
    /// Expects a compiled model named "FaceNet" with extension `.mlmodelc`.
    /// (You should convert `facenet.tflite` → `FaceNet.mlpackage` using
    /// `model_converter.py`, drag it into Xcode, and ensure target membership.)
    private func loadFaceNetModelIfNeeded() {
        guard faceNetModel == nil else { return }
        
        let bundle = Bundle(for: FaceNetModelHandler.self)
        
        // Try compiled Core ML model
        if let url = bundle.url(forResource: "FaceNet", withExtension: "mlmodelc") {
            do {
                let config = MLModelConfiguration()
                faceNetModel = try MLModel(contentsOf: url, configuration: config)
                print("✅ Loaded FaceNet Core ML model from bundle")
            } catch {
                print("❌ Failed to load FaceNet Core ML model: \(error.localizedDescription)")
            }
        } else {
            print("⚠️ FaceNet Core ML model not found in bundle (FaceNet.mlmodelc)")
        }
    }

    private func loadGenderNetModel() {
        guard genderNetModel == nil else { return }

        let bundle = Bundle(for: FaceNetModelHandler.self)

        if let url = bundle.url(forResource: "GenderNet", withExtension: "mlmodel") {
            do {
                let config = MLModelConfiguration()
                genderNetModel = try MLModel(contentsOf: url, configuration: config)
                print("✅ Loaded GenderNet Core ML model from bundle")
            } catch {
                print("❌ Failed to load GenderNet Core ML model: \(error.localizedDescription)")
            }
        } else {
            print("⚠️ GenderNet Core ML model not found in bundle (GenderNet.mlmodel)")
        }
    }
    
    /// Try to get embedding using FaceNet Core ML model (expected 512-d output)
    private func getEmbeddingWithFaceNet(from faceImage: UIImage) -> [Float]? {
        loadFaceNetModelIfNeeded()
        guard let model = faceNetModel else { return nil }
        
        // Resize to FaceNet input size (160x160) as used in model_converter.py
        let targetSize = CGSize(width: 160, height: 160)
        guard let resized = resize(image: faceImage, targetSize: targetSize),
              let pixelBuffer = pixelBuffer(from: resized, width: 160, height: 160) else {
            print("❌ Failed to create pixel buffer for FaceNet input")
            return nil
        }
        
        do {
            // Input name must match model_converter.py ("input_1")
            let input = try MLDictionaryFeatureProvider(dictionary: [
                "input_1": pixelBuffer
            ])
            let output = try model.prediction(from: input)
            
            // Take the first multi-array output as embedding
            guard let firstName = output.featureNames.first,
                  let feature = output.featureValue(for: firstName),
                  let array = feature.multiArrayValue else {
                print("❌ FaceNet model output missing MLMultiArray")
                return nil
            }
            
            let count = array.count
            var embedding = [Float](repeating: 0, count: count)
            for i in 0..<count {
                embedding[i] = Float(truncating: array[i])
            }
            
            return embedding
        } catch {
            print("❌ FaceNet Core ML prediction failed: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - Vision (FeaturePrint) fallback
    
    /// Use Apple's Vision feature print (generic image descriptor) as fallback.
    /// This typically returns a 2048-d float vector.
    private func getEmbeddingWithVision(from faceImage: UIImage) -> [Float]? {
        guard let cgImage = faceImage.cgImage else {
            print("❌ Invalid face image")
            return nil
        }
        
        let request = VNGenerateImageFeaturePrintRequest()
        request.imageCropAndScaleOption = .scaleFit
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        do {
            try handler.perform([request])
            
            guard let result = request.results?.first as? VNFeaturePrintObservation else {
                print("❌ No valid feature print output from Vision")
                return nil
            }
            
            let elementCount = result.elementCount
            var floats = [Float](repeating: 0, count: elementCount)
            
            result.data.withUnsafeBytes { (pointer: UnsafeRawBufferPointer) in
                if let baseAddress = pointer.baseAddress {
                    let floatPointer = baseAddress.bindMemory(to: Float.self, capacity: elementCount)
                    for i in 0..<elementCount {
                        floats[i] = floatPointer[i]
                    }
                }
            }
            
            return floats
        } catch {
            print("❌ Vision FeaturePrint failed: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - Helpers
    
    /// Ensure embedding has exactly `targetSize` elements by trimming or padding.
    private func ensureEmbeddingSize(_ embedding: [Float], targetSize: Int) -> [Float] {
        if embedding.count == targetSize {
            return embedding
        } else if embedding.count > targetSize {
            // Trim to first `targetSize` elements
            return Array(embedding.prefix(targetSize))
        } else {
            // Pad with zeros
            var padded = embedding
            padded.append(contentsOf: Array(repeating: 0, count: targetSize - embedding.count))
            return padded
        }
    }
    
    /// Resize UIImage to target size
    private func resize(image: UIImage, targetSize: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(targetSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: targetSize))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return newImage
    }
    
    /// Convert UIImage to CVPixelBuffer (BGRA)
    private func pixelBuffer(from image: UIImage, width: Int, height: Int) -> CVPixelBuffer? {
        let attrs: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ]
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault,
                                         width,
                                         height,
                                         kCVPixelFormatType_32BGRA,
                                         attrs as CFDictionary,
                                         &pixelBuffer)
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            return nil
        }
        
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        
        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
        ) else {
            return nil
        }
        
        guard let cgImage = image.cgImage else { return nil }
        let rect = CGRect(x: 0, y: 0, width: width, height: height)
        context.clear(rect)
        context.draw(cgImage, in: rect)
        
        return buffer
    }
}
