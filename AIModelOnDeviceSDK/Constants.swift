//
//  Constants.swift
//  HPIkeaSampleApp
//
//  Created by Vinit Chapla on 16/12/25.
//

import Foundation
import UIKit

public struct SDKOptions {
    public let persionalisationType : PersionalisationType
    public let photoSelectionType : PhotoSelectionType
    public let locationRadius : Double
    
    public init(persionalisationType: PersionalisationType, photoSelectionType: PhotoSelectionType, locationRadius : Double = 500) {
        self.persionalisationType = persionalisationType
        self.photoSelectionType = photoSelectionType
        self.locationRadius = locationRadius
    }
}

public enum PhotoSelectionType {
    case auto
    case manual
}

public enum PersionalisationType {
    case homegoods
    case fashion
    case all
    case unKnown
}

// Furniture categories (COCO dataset)
public let furnitureCategories: Set<String> = [
    "chair", "couch", "bed", "dining table", "desk",
    "refrigerator", "sofa",
    "table", "ottoman"
]

// Categories to exclude from verification calculations (but still show in detection results)
public let excludedCategories: Set<String> = [
    "bowl", "bowls",
    "banana", "bananas",
    "crockery",
    "fruit", "fruits",
    "apple", "apples",
    "orange", "oranges",
    "plate", "plates",
    "cup", "cups",
    "fork", "forks",
    "knife", "knives",
    "spoon", "spoons"
]

public enum TagerAPIResultCategory : String {
    case bed_room       = "bedroom"
    case living_room    = "living_room"
    case dining_room    = "dining_room"
    case male            = "male"
    case female          = "female"
    case kidMale        = "kid_male"
    case kidFemale      = "kid_female"
    case unknown = "unknown"
    
    var arrProductCategory : [String] {
        switch self {
        case .bed_room :
            return ["beds", "bed", "bedroom"]
        case .living_room :
            return ["sofas", "sofa", "armchair", "armchairs", "living_room"]
        case .dining_room :
            return ["tables", "table", "dining", "dining_room"]
        case .unknown , .male , .female, .kidMale, .kidFemale :
            return []
        }
    }
}

public enum PersonalizationError: LocalizedError {
    case noPhotosFound
    case insufficientPhotos
    case failedToLoadImages
    case noValidImages
    case noImagesForCategory
    case noValidFaceFound
    
    public var errorDescription: String? {
        switch self {
        case .noPhotosFound:
            return "No photos with location data found"
        case .insufficientPhotos:
            return "Not enough photos in cluster"
        case .failedToLoadImages:
            return "Failed to load images from cluster"
        case .noValidImages:
            return "No valid images found after filtering"
        case .noImagesForCategory:
            return "No images available for this category"
        case .noValidFaceFound:
            return "No valid face found in images"
        }
    }
}


