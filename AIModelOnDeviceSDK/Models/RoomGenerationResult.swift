//
//  RoomGenerationResult.swift
//  AIModelOnDeviceSDK
//
//  Created on 25/11/25.
//

import Foundation
#if os(iOS)
import UIKit
#endif

/// Room generation result with generated image
public struct RoomGenerationResult: Identifiable {
    public let id = UUID()
    public let category: String
    public let roomImage: UIImage // Original room image from tagger API
    public let objectImage: UIImage // Object image used (sofa/bed/table)
    public let generatedImage: UIImage // Generated room image from API
    public let roomType: String // living_room, bedroom, dining_room
    
    public init(category: String, roomImage: UIImage, objectImage: UIImage, generatedImage: UIImage, roomType: String) {
        self.category = category
        self.roomImage = roomImage
        self.objectImage = objectImage
        self.generatedImage = generatedImage
        self.roomType = roomType
    }
}

/// Complete room generation results for all categories
public struct RoomGenerationCompleteResult {
    public let results: [RoomGenerationResult]
    public let totalGenerated: Int
    
    public init(results: [RoomGenerationResult]) {
        self.results = results
        self.totalGenerated = results.count
    }
}

