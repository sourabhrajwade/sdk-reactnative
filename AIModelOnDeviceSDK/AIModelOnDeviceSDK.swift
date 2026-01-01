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
//  let sdk = AIModelSDK.shared
//  sdk.runPersonalizationService(...) { result in ... }
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
/// let sdk = AIModelSDK.shared
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
    public let arrPersonalizeAsset : [PersonalizedAsset]
}

public struct PersonalizedAsset {
    public let phAsset : PHAsset?
    public var validCategory: TaggerAPIResultCategory
}


public enum SDKState {
    case analyzing
    case clustering
    case selectingBestPhoto
    case tagging
    case complete
    case error
    
    public var message : String {
        switch self {
        case .analyzing:
            "Analyzing photos..."
        case .clustering:
            "Clustering photos..."
        case .selectingBestPhoto:
            "Selecting best photo..."
        case .tagging:
            "Tagging photos..."
        case .complete:
            "Personalization Complete"
        case .error:
            "Personalization error"
        }
    }
}


public struct SDKVendor {
    public let personalizationType : PersonalizationType
    public let arrSDKCategory : [SDKCategory]
    
    public init(personalizationType: PersonalizationType, arrSDKCategory: [SDKCategory]) {
        self.personalizationType = personalizationType
        self.arrSDKCategory = arrSDKCategory
    }
}

public struct SDKCategory: Identifiable, Hashable {
    public let id: Int
    public let vendorId: Int
    public let name: String
    public let displayName: String
    public let slug: String
    public let categoryUrl: String
    public let description: String?
    public let imageUrl: String?
    public let createdAt: String
    public let productCount: Int?
    
    public init(
        id: Int,
        vendorId: Int,
        name: String,
        displayName: String,
        slug: String,
        categoryUrl: String,
        description: String?,
        imageUrl: String?,
        createdAt: String,
        productCount: Int?
    ) {
        self.id = id
        self.vendorId = vendorId
        self.name = name
        self.displayName = displayName
        self.slug = slug
        self.categoryUrl = categoryUrl
        self.description = description
        self.imageUrl = imageUrl
        self.createdAt = createdAt
        self.productCount = productCount
    }
}

public struct PersonalisationImageResult {
    public let productUrl : String
    public let resultImage: UIImage?
    
    public init(productUrl: String, resultImage: UIImage?) {
        self.productUrl = productUrl
        self.resultImage = resultImage
    }
}

public struct ClusterImage {
    public let identifier: String
    public let image: UIImage
    
    public init(image: UIImage, identifier: String) {
        self.image = image
        self.identifier = identifier
    }
}

public class AIModelSDK {
    
    public static let shared = AIModelSDK()
    
    public var sdkOptions : SDKOptions = SDKOptions(personalizationType: .all, photoSelectionType: .auto)
        
    private init() {
        
    }
    //Auto Service
    public func runPersonalizationService(sdkOptions: SDKOptions,progress: @escaping (SDKState) -> Void, completion: @escaping (Result<SDKResult, Error>) -> Void) async{
        self.sdkOptions = SDKOptions(personalizationType: sdkOptions.personalizationType, photoSelectionType: .auto)
        do {
            try await SDKPersonalizationService.shared.runPersonalizationPipeline(
                progressUpdate: progress, completion: completion)
        } catch {
                completion(.failure(error))
        }
    }
    //Manual Service
    public func runPersonalizationServiceWith(sdkOptions: SDKOptions,arrPHAssets:[PHAsset],progress: @escaping (SDKState) -> Void, completion: @escaping (Result<SDKResult, Error>) -> Void) async{
        self.sdkOptions = sdkOptions
        do {
            try await SDKPersonalizationService.shared.runPersonalizationPipelineWith(
                arrPHAssets: arrPHAssets, progressUpdate: progress, completion: completion)
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
        completion: @escaping (Result<PersonalisationImageResult, Error>) -> Void
    ) {
        TaggerAPIHandler.shared.generateRoom(thumbnailImg: thumbnailImg, roomType: roomType,objectUrl: objectUrl, completion: completion)
    }
    
    public func generateFashion(
        thumbnailImg: UIImage,
        garmentImageUrl: String,
        productType:String,
        completion: @escaping (Result<PersonalisationImageResult, Error>) -> Void
    ) {
        TaggerAPIHandler.shared.generateFashion( thumbnailImg: thumbnailImg, garmentImageUrl: garmentImageUrl, productType: productType, completion: completion)
    }
}

