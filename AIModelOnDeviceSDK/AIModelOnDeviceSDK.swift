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
import Photos

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
///

public struct SDKResult {
    public let success : Bool
    public let message : String
    public let arrHomeGoodsAssest : [PersionalizeAssest]?
    public let arrFashionAssest : [PersionalizeAssest]?
}

public struct PersionalizeAssest {
    public let phAsset : PHAsset?
    public let bestPickResult : BestPickResult
}

public enum SDKState {
    case analyzing
    case clusturing
    case selectingBestPhoto
    case tagging
    case complete
    case error
    
    public var message : String {
        switch self {
        case .analyzing:
            "Analyzing photos..."
        case .clusturing:
            "Clusturing photos..."
        case .selectingBestPhoto:
            "Selecting best photo..."
        case .tagging:
            "Tagging photos..."
        case .complete:
            "Persionalization Complete"
        case .error:
            "Personalization error"
        }
    }
}


public class AIModelOnDeviceSDK {
    
    public static let shared = AIModelOnDeviceSDK()
    
    public var sdkOptions : SDKOptions = SDKOptions(persionalisationType: .all, photoSelectionType: .auto)
    
    private init() {
        
    }
    //Auto Service
    public func runPersonalizationService(sdkOptions: SDKOptions,progress: @escaping (SDKState) -> Void, completion: @escaping (Result<SDKResult, Error>) -> Void) async{
        self.sdkOptions = SDKOptions(persionalisationType: sdkOptions.persionalisationType, photoSelectionType: .auto)
        do {
            try await SDKPersonalizationService.shared.runPersonalizationPipeline(
                progressUpdate: progress, complition: completion)
        } catch {
                completion(.failure(error))
        }
    }
    //Manual Service
    public func runPersonalizationServiceWith(sdkOptions: SDKOptions,arrPHAssesst:[PHAsset],progress: @escaping (SDKState) -> Void, completion: @escaping (Result<SDKResult, Error>) -> Void) async{
        self.sdkOptions = sdkOptions
        do {
            try await SDKPersonalizationService.shared.runPersonalizationPipelineWith(
                arrPHAssesst: arrPHAssesst, progressUpdate: progress, complition: completion)
        } catch {
                completion(.failure(error))
        }
    }
    public func generateFurniture(
        thumbnailImg: UIImage,
        roomType: String,
        roomImageUrl: String? = nil,
        objectUrl: String,
        objectImage: UIImage? = nil,
        completion: @escaping (Result<PersionalisationImageResult, Error>) -> Void
    ) {
        TaggerAPIHandler.shared.generateRoom(thumbnailImg: thumbnailImg, roomType: roomType,objectUrl: objectUrl, completion: completion)
    }
    
    public func generateFashion(
        thumbnailImg: UIImage,
        garmentImageUrl: String,
        productType:String,
        categorySlug:String,
        completion: @escaping (Result<PersionalisationImageResult, Error>) -> Void
    ) {
        TaggerAPIHandler.shared.generateFashion( thumbnailImg: thumbnailImg, garmentImageUrl: garmentImageUrl, productType: productType,categorySlug:categorySlug, completion: completion)
    }
}

