//
//  VerificationResult.swift
//  AIModelOnDeviceSDK
//
//  Created on 14/11/25.
//

import Foundation
import UIKit

/// Verification result for interior image verification
public struct VerificationResult {
    public var isValid: Bool = false
    public var score: Double = 0.0
    public var detections: [DetectionResult] = []
    public var filterResults: [FilterResult] = []
    public var scoreBreakdown: ScoreBreakdown?
    public var totalLatency: Double = 0.0
    
    public var status: String {
        return isValid ? "✅ Valid Interior Image" : "❌ Invalid Image"
    }
    
    public init() {}
}

/// Filter result details
public struct FilterResult: Identifiable {
    public let id = UUID()
    public let name: String
    public let passed: Bool
    public let message: String
    public let value: String
    public let latency: Double
    
    public var icon: String {
        return passed ? "checkmark.circle.fill" : "xmark.circle.fill"
    }
    
    public var color: String {
        return passed ? "green" : "red"
    }
}

/// Score breakdown for verification
public struct ScoreBreakdown: Codable {
    public let furnitureCoverageScore: Double
    public let spreadScore: Double
    public let compositionScore: Double
    public let colorScore: Double
    public let finalScore: Double
    
    public var furnitureCoverageWeight: Double { 0.4 }
    public var spreadWeight: Double { 0.25 }
    public var compositionWeight: Double { 0.25 }
    public var colorWeight: Double { 0.10 }
    
    public init(furnitureCoverageScore: Double, spreadScore: Double, compositionScore: Double, colorScore: Double, finalScore: Double) {
        self.furnitureCoverageScore = furnitureCoverageScore
        self.spreadScore = spreadScore
        self.compositionScore = compositionScore
        self.colorScore = colorScore
        self.finalScore = finalScore
    }
}

/// Image verification result wrapper containing both image and verification result
public struct ImageVerificationResult: Identifiable {
    public let id = UUID()
    public let image: UIImage
    public let result: VerificationResult
    public let index: Int
    
    public init(image: UIImage, result: VerificationResult, index: Int) {
        self.image = image
        self.result = result
        self.index = index
    }
}

