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
class FaceNetModelHandler {
    
    public static let shared = FaceNetModelHandler()
    
    /// Lazily loaded Core ML model for FaceNet
    private var genderClassifierModel: VNCoreMLModel?

    private init() {
        loadGenderNetModel()
    }
    
    // MARK: - Public API
    
    private func classifyGenderWithGenderNet(from image: UIImage) async -> TaggerAPIResultCategory {
        return await withCheckedContinuation { continuation in
            autoreleasepool {
                guard let cgImage = image.cgImage else {
                    print("❌ FaceNet: Invalid CGImage")
                    continuation.resume(returning: TaggerAPIResultCategory.unknown)
                    return
                }

                guard let model = genderClassifierModel else {
                    print("❌ FaceNet: Model not loaded")
                    continuation.resume(returning: TaggerAPIResultCategory.unknown)
                    return
                }
                
                // 1. Detect Face First
//                let faceRequest = VNDetectFaceRectanglesRequest()
//                let faceHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
//                
//                var imageToClassify = cgImage
                
//                do {
//                    try faceHandler.perform([faceRequest])
//                    if let faces = faceRequest.results, let face = faces.first {
//                        // Crop to face
//                        let boundingBox = face.boundingBox
//                        let width = CGFloat(cgImage.width)
//                        let height = CGFloat(cgImage.height)
//                        
//                        // Convert Vision rect (normalized, bottom-left origin) to CG rect (pixels, top-left origin)
//                        let x = boundingBox.origin.x * width
//                        let y = (1 - boundingBox.origin.y - boundingBox.height) * height
//                        let w = boundingBox.width * width
//                        let h = boundingBox.height * height
//                        
//                        let cropRect = CGRect(x: x, y: y, width: w, height: h)
//                        if let cropped = cgImage.cropping(to: cropRect) {
//                            imageToClassify = cropped
//                            print("✅ FaceNet: Face detected and cropped")
//                        }
//                    } else {
//                        print("⚠️ FaceNet: No face detected, using full image")
//                    }
//                } catch {
//                    print("⚠️ FaceNet: Face detection failed: \(error.localizedDescription)")
//                }

                // 2. Classify Gender
                let request = VNCoreMLRequest(model: model)
                request.imageCropAndScaleOption = .scaleFill // Ensure the image fills the model input
                
                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

                do {
                    try handler.perform([request])
                } catch {
                    print("❌ FaceNet: Failed to perform classification: \(error.localizedDescription)")
                    continuation.resume(returning: TaggerAPIResultCategory.unknown)
                    return
                }

                if let results = request.results as? [VNClassificationObservation] {
                    // Check all results
                    for result in results {
                        print("🔍 FaceNet Result: \(result.identifier) - \(result.confidence)")
                    }
                    
                    let sortedResults = results.sorted { $0.confidence > $1.confidence }
                    if let topResult = sortedResults.first {
                        // Lower threshold to 0.6 and handles both case-sensitivities
                        if topResult.confidence > 0.6 {
                            let id = topResult.identifier.lowercased()
                            if id.contains("male") && !id.contains("female") {
                                continuation.resume(returning: TaggerAPIResultCategory.male)
                                return
                            } else if id.contains("female") {
                                continuation.resume(returning: TaggerAPIResultCategory.female)
                                return
                            }
                        }
                    }
                }
                print("⚠️ FaceNet: Classification returned unknown/low confidence")
                continuation.resume(returning: TaggerAPIResultCategory.unknown)
                return
            }
        }
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
    public func classifyGender(from faceImage: UIImage) async -> TaggerAPIResultCategory {
        return await classifyGenderWithGenderNet(from: faceImage)
    }
    
    // MARK: - Core ML (GenderClassifierModel) path

    private func loadGenderNetModel() {
        guard genderClassifierModel == nil else { return }

        genderClassifierModel = try? VNCoreMLModel(for: Gender_FastViT().model)
    }
    
}
