//
//  DetectionResult.swift
//  AIModelOnDeviceSDK
//
//  Created on 14/11/25.
//

import Foundation
import UIKit

/// Detection result structure for object detection
public struct DetectionResult: Codable, Identifiable {
    public let id = UUID()
    public let label: String
    public let confidence: Float
    public let boundingBox: BoundingBox
    public let areaPercentage: Float
    
    public var confidencePercentage: String {
        return String(format: "%.1f%%", confidence * 100)
    }
    
    public var areaPercentageString: String {
        return String(format: "%.2f%%", areaPercentage * 100)
    }
    
    enum CodingKeys: String, CodingKey {
        case label, confidence, boundingBox, areaPercentage
    }
}

/// Bounding box structure
public struct BoundingBox: Codable {
    public let x: Float
    public let y: Float
    public let width: Float
    public let height: Float
    
    public init(x: Float, y: Float, width: Float, height: Float) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
    
    /// Get normalized (0-1) coordinates
    public var normalizedRect: CGRect {
        return CGRect(x: CGFloat(x), y: CGFloat(y), width: CGFloat(width), height: CGFloat(height))
    }
    
    /// Calculate area percentage
    public var area: Float {
        return width * height
    }
}

