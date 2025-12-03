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
    public var error: Error? // Error if API call failed
    public var errorMessage: String? // Human-readable error message
    public let timestamp: Date
    
    public init(
        id: String,
        productId: Int? = nil,
        categoryId: Int? = nil,
        roomType: String,
        objectUrl: String,
        generatedImageUrl: String? = nil,
        generatedImage: UIImage? = nil,
        error: Error? = nil,
        errorMessage: String? = nil
    ) {
        self.id = id
        self.productId = productId
        self.categoryId = categoryId
        self.roomType = roomType
        self.objectUrl = objectUrl
        self.generatedImageUrl = generatedImageUrl
        self.generatedImage = generatedImage
        self.error = error
        self.errorMessage = errorMessage
        self.timestamp = Date()
    }
    
    /// Update with the generated image response
    public mutating func updateWithResponse(image: UIImage?, imageUrl: String?) {
        self.generatedImage = image
        self.generatedImageUrl = imageUrl
        // Clear error if we got a successful response
        self.error = nil
        self.errorMessage = nil
    }
    
    /// Update with error response
    public mutating func updateWithError(_ error: Error, message: String? = nil) {
        self.error = error
        self.errorMessage = message ?? error.localizedDescription
        // Clear success data if we got an error
        self.generatedImage = nil
        self.generatedImageUrl = nil
    }
    
    /// Check if request failed
    public var hasError: Bool {
        return error != nil
    }
    
    /// Check if request succeeded
    public var isSuccess: Bool {
        return generatedImageUrl != nil && error == nil
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
    
    /// Update a request with error
    public mutating func updateRequestWithError(id: String, error: Error, message: String? = nil) {
        guard var request = requests[id] else { return }
        request.updateWithError(error, message: message)
        requests[id] = request
    }
    
    /// Get all failed requests
    public func getFailedRequests() -> [PersonalizationRequest] {
        return requests.values.filter { $0.hasError }
    }
    
    /// Get all successful requests
    public func getSuccessfulRequests() -> [PersonalizationRequest] {
        return requests.values.filter { $0.isSuccess }
    }
    
    /// Check if any requests failed
    public var hasFailures: Bool {
        return requests.values.contains { $0.hasError }
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

