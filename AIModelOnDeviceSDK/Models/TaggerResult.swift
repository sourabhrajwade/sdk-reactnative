//
//  TaggerResult.swift
//  AIModelOnDeviceSDK
//
//  Created on 25/11/25.
//

import Foundation
import UIKit

/// Image with its identifier for tagger API
public struct ImageWithID {
    public let image: UIImage
    public let identifier: String // PHAsset localIdentifier or custom ID
    
    public init(image: UIImage, identifier: String) {
        self.image = image
        self.identifier = identifier
    }
}

/// Tagger API response metadata
public struct TaggerMeta: Codable {
    public let totalImages: Int
    public let latencySeconds: Double
    public let timestamp: Double
    
    enum CodingKeys: String, CodingKey {
        case totalImages = "total_images"
        case latencySeconds = "latency_seconds"
        case timestamp
    }
}

/// Best pick for a room category
public struct BestPick: Codable {
    public let filename: String
    public let score: Double
    public let id: Int
}

/// Best picks for all room categories
public struct BestPicks: Codable {
    public let livingRoom: BestPick?
    public let dining: BestPick?
    public let bathroom: BestPick?
    public let kitchen: BestPick?
    public let bedroom: BestPick?
    
    enum CodingKeys: String, CodingKey {
        case livingRoom = "living_room"
        case dining
        case bathroom
        case kitchen
        case bedroom
    }
}

/// Individual image tagger result
public struct TaggerImageResult: Codable {
    public let id: Int
    public let filename: String
    public let category: String? // Optional because API can return null
    public let score: Double
    public let status: String
}

/// Complete tagger API response
public struct TaggerResponse: Codable {
    public let meta: TaggerMeta
    public let bestPicks: BestPicks
    public let data: [TaggerImageResult]
    
    enum CodingKeys: String, CodingKey {
        case meta
        case bestPicks = "best_picks"
        case data
    }
}

/// Tagger result with mapped image
public struct TaggerResult: Identifiable {
    public let id: UUID
    public let image: UIImage
    public let identifier: String
    public let taggerResult: TaggerImageResult
    
    public init(image: UIImage, identifier: String, taggerResult: TaggerImageResult) {
        self.id = UUID()
        self.image = image
        self.identifier = identifier
        self.taggerResult = taggerResult
    }
}

/// Best pick result with mapped image
public struct BestPickResult {
    public let category: String
    public let image: UIImage
    public let identifier: String
    public let bestPick: BestPick
    
    public init(category: String, image: UIImage, identifier: String, bestPick: BestPick) {
        self.category = category
        self.image = image
        self.identifier = identifier
        self.bestPick = bestPick
    }
}

/// Complete tagger result with all mapped images
public struct TaggerCompleteResult {
    public let meta: TaggerMeta
    public let bestPicks: [BestPickResult]
    public let results: [TaggerResult]
    
    public init(meta: TaggerMeta, bestPicks: [BestPickResult], results: [TaggerResult]) {
        self.meta = meta
        self.bestPicks = bestPicks
        self.results = results
    }
}

