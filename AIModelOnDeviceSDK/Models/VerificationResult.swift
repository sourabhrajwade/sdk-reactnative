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
    public var scoreBreakdown: ScoreBreakdown?
    public var totalLatency: Double = 0.0
    
    public var status: String {
        return isValid ? "✅ Valid Interior Image" : "❌ Invalid Image"
    }
    
    public init() {}
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

