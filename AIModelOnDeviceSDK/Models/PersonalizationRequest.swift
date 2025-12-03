//
//  PersonalizationRequest.swift
//  AIModelOnDeviceSDK
//
//  Model to track API requests and responses for personalization
//

import Foundation
import UIKit

/// Tracks a personalization API request and its response
public struct PersonalizationRequest: Identifiable {
    public let id: String // Unique identifier (e.g., "product-123")
    public let productId: Int?
    public let categoryId: Int?
    public let roomType: String
    public let objectUrl: String // The product image URL sent to API
    public var generatedImageUrl: String? // The returned image URL (base64 data URL)
    public var generatedImage: UIImage? // The returned UIImage (stored separately in cache)
    public let timestamp: Date
    
    public init(
        id: String,
        productId: Int? = nil,
        categoryId: Int? = nil,
        roomType: String,
        objectUrl: String,
        generatedImageUrl: String? = nil,
        generatedImage: UIImage? = nil
    ) {
        self.id = id
        self.productId = productId
        self.categoryId = categoryId
        self.roomType = roomType
        self.objectUrl = objectUrl
        self.generatedImageUrl = generatedImageUrl
        self.generatedImage = generatedImage
        self.timestamp = Date()
    }
    
    /// Update with the generated image response
    public mutating func updateWithResponse(image: UIImage?, imageUrl: String?) {
        self.generatedImage = image
        self.generatedImageUrl = imageUrl
    }
}

/// Collection of personalization requests for tracking
public struct PersonalizationRequestMap {
    private var requests: [String: PersonalizationRequest] = [:]
    
    /// Public initializer
    public init() {
        self.requests = [:]
    }
    
    /// Add or update a request
    public mutating func addRequest(_ request: PersonalizationRequest) {
        requests[request.id] = request
    }
    
    /// Update a request with response
    public mutating func updateRequest(id: String, image: UIImage?, imageUrl: String?) {
        guard var request = requests[id] else { return }
        request.updateWithResponse(image: image, imageUrl: imageUrl)
        requests[id] = request
    }
    
    /// Get request by ID
    public func getRequest(id: String) -> PersonalizationRequest? {
        return requests[id]
    }
    
    /// Get all requests
    public func getAllRequests() -> [PersonalizationRequest] {
        return Array(requests.values)
    }
    
    /// Get requests by product ID
    public func getRequests(forProductId productId: Int) -> [PersonalizationRequest] {
        return requests.values.filter { $0.productId == productId }
    }
    
    /// Get requests by category ID
    public func getRequests(forCategoryId categoryId: Int) -> [PersonalizationRequest] {
        return requests.values.filter { $0.categoryId == categoryId }
    }
    
    /// Clear all requests
    public mutating func clear() {
        requests.removeAll()
    }
    
    /// Get count
    public var count: Int {
        return requests.count
    }
}

