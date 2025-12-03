//
//  PersonalizationResult.swift
//  AIModelOnDeviceSDK
//
//  Result object returned by SDK after personalization
//

import Foundation
import UIKit

/// Complete result from personalization pipeline
public struct PersonalizationResult {
    /// Map of product ID to generated image URL (base64 data URL)
    public let productImageMap: [Int: String]
    
    /// Map of category ID to generated image URL (base64 data URL)
    public let categoryImageMap: [Int: String]
    
    /// Complete request tracking map
    public let requestMap: PersonalizationRequestMap
    
    /// All generated images cached by the SDK
    public let cachedImages: [String: UIImage] // key -> UIImage
    
    /// Whether any API calls failed
    public let hasErrors: Bool
    
    /// Array of all failed requests with error information
    public let failedRequests: [PersonalizationRequest]
    
    public init(
        productImageMap: [Int: String] = [:],
        categoryImageMap: [Int: String] = [:],
        requestMap: PersonalizationRequestMap = PersonalizationRequestMap(),
        cachedImages: [String: UIImage] = [:]
    ) {
        self.productImageMap = productImageMap
        self.categoryImageMap = categoryImageMap
        self.requestMap = requestMap
        self.cachedImages = cachedImages
        self.hasErrors = requestMap.hasFailures
        self.failedRequests = requestMap.getFailedRequests()
    }
}

