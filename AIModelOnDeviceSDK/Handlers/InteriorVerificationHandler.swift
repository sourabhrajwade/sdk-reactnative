//
//  InteriorVerificationHandler.swift
//  AIModelOnDeviceSDK
//
//  Created on 14/11/25.
//

import Foundation
import UIKit
import Vision
import CoreML
import CoreImage

/// Handler for interior image verification
class InteriorVerificationHandler {
    
    public static let shared = InteriorVerificationHandler()
    
    private init() {}
    
    private let roomObjectWeights: [RoomType: [String: Int]] = [
        .bedroom: [
            "bed": 6, "wardrobe": 4, "lamp": 2, "nightstand": 3
        ],
        .livingRoom: [
            "sofa": 6, "tv": 5, "coffee table": 4, "rug": 2
        ],
        .diningRoom: [
            "dining table": 6, "table": 4, "chair": 2
        ]
    ]
    
    private func classifyRoom(_ detections: [DetectionResult]) -> RoomType {
        guard !detections.isEmpty else { return .emptyRoom }
        
        var scores: [RoomType: Int] = [:]
        
        for d in detections {
            let label = d.label.lowercased()
            for (room, weights) in roomObjectWeights {
                if let w = weights[label] {
                    scores[room, default: 0] += w
                }
            }
        }
        
        guard let best = scores.max(by: { $0.value < $1.value }),
              best.value > 0 else {
            return .unknown
        }
        return best.key
    }
    
    private func classifyPerson(_ persons: [DetectionResult]) -> (PersonType,confidenceScore:Float) {
        guard !persons.isEmpty else { return (.none,0.0) }
        
        let coverage = persons.reduce(0.0) { $0 + Double($1.areaPercentage) }
        
        if persons.count == 1 {
            return coverage > 0.35 ? (.single,persons.first?.confidence ?? 0.0) : (.none,0.0)
        }
        
        return (.multiple,persons.first?.confidence ?? 0.0)
    }
    
    
    
    func verifyImage(
        _ image: UIImage,
        using modelType: YOLOModel,
        completion: @escaping (PhotoVerificationResult) -> Void
    ) {
        let startTime = CFAbsoluteTimeGetCurrent()
        var result = PhotoVerificationResult()
        
        ObjectDetectionModelHandler.shared.detectRooms(image) { [weak self] detections, _ in
            guard let self = self, let detections = detections else {
                result.isValid = false
                completion(result)
                return
            }
            
            result.arrDetectionResult = detections
            
            //            let relevant = detections.filter {
            //                !excludedCategories.contains($0.label.lowercased())
            //            }
            //
            //            let persons = relevant.filter { $0.label.lowercased() == "person" }
            //            let furniture = relevant.filter {
            //                furnitureCategories.contains($0.label.lowercased())
            //            }
            //            // ----- EMPTY ROOM -----
            //            if furniture.isEmpty && persons.isEmpty {
            //                result.isValid = false
            //                result.validCategory = .unknown
            //                completion(result)
            //                return
            //            }
            // 🔥 CLASSIFICATIONS
            //            let roomType = self.classifyRoom(furniture)
            //            let personType = self.classifyPerson(persons)
            
            // ----- PERSON-FIRST IMAGE -----
            //            if (personType.0) == .single {
            //                Task {
            //                    let category = await FaceNetModelHandler.shared.classifyGender(from: image)
            //                    result.isValid = true
            //                    result.validCategory = category
            //                    result.score = Double(personType.confidenceScore)
            //                    completion(result)
            //                }
            //                return
            //            }
            
            // ----- INTERIOR VALIDATION -----
            //            let furnitureCoverage = furniture.reduce(0.0) { $0 + Double($1.areaPercentage) }
            //            if furnitureCoverage < 0.03 || furnitureCoverage > 0.85 {
            //                result.isValid = false
            //                completion(result)
            //                return
            //            }
            
            //            let spreadScore = self.calculateSpreadScore(furniture)
            //            let colorScore = self.calculateColorVariance(image)
            //            let compositionScore = self.calculateCompositionScore(furniture)
            //
            //            let coverageScore = self.normalizeCoverageScore(furnitureCoverage)
            //
            //            let finalScore =
            //                0.4 * coverageScore +
            //                0.25 * spreadScore +
            //                0.25 * compositionScore +
            //                0.10 * colorScore
            //
            //            result.isValid = true
            //            switch roomType {
            //            case .bedroom:
            //                result.validCategory = .bed_room
            //            case .diningRoom:
            //                result.validCategory = .dining_room
            //            case .livingRoom:
            //                result.validCategory = .living_room
            //            default :
            //                result.isValid = false
            //                result.validCategory = .unknown
            //            }
            
            //            result.score = finalScore
            result.isValid = true
            result.score = Double(detections.first?.confidence ?? 0.0)
            result.totalLatency = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
            
            
            let roomType = RoomType(rawValue: detections.first?.label.lowercased() ?? "")
            switch roomType {
            case .bedroom:
                result.validCategory = .bed_room
            case .diningRoom:
                result.validCategory = .dining_room
            case .livingRoom:
                result.validCategory = .living_room
            default :
                result.isValid = false
                result.validCategory = .unknown
            }
            completion(result)
        }
    }
    func filterPhotoResults(
        _ images: [PhotoDetectionData],
        using modelType: YOLOModel,
        completion: @escaping ([PhotoDetectionData]) -> Void
    ) {
        
        guard !images.isEmpty else {
            completion([])
            return
        }
        let batchSize = 3 // Process 3 images at a time to manage memory
        var allResults: [PhotoDetectionData] = []
        let resultQueue = DispatchQueue(label: "com.aimodelondevice.filterResults", attributes: .concurrent)
        let dispatchGroup = DispatchGroup()
        
        // Process images in batches to manage memory
        DispatchQueue.global(qos: .userInitiated).async {
            let semaphore = DispatchSemaphore(value: batchSize) // Limit concurrent operations
            
            for (clusterImage) in images {
                // Wait if we've reached the batch limit
                semaphore.wait()
                
                dispatchGroup.enter()
                
                // Use autoreleasepool to release memory after each image
                autoreleasepool { [weak self] in
                    guard let self = self else {
                        semaphore.signal()
                        dispatchGroup.leave()
                        return
                    }
                    
                    self.verifyImage(clusterImage.image, using: modelType) { result in
                        defer {
                            semaphore.signal() // Signal when done
                            dispatchGroup.leave()
                        }
                        
                        // Only include valid results with scoreBreakdown
                        if result.isValid {
                            clusterImage.photoVerificationResult = result
                            resultQueue.async(flags: .barrier) {
                                allResults.append(clusterImage)
                            }
                        }
                    }
                }
            }
            
            // Wait for all verifications to complete
            dispatchGroup.notify(queue: .main) {
                //                // Sort by scoreBreakdown.finalScore (highest first)
                //                let sortedResults = allResults.sorted { first, second in
                //                    let firstScore = first.photoVerificationResult?.scoreBreakdown?.finalScore ?? 0.0
                //                    let secondScore = second.photoVerificationResult?.scoreBreakdown?.finalScore ?? 0.0
                //                    return firstScore > secondScore
                //                }
                completion(allResults)
            }
        }
    }
    // Normalize person coverage to 0-1 score (peak at ~40-60% for good framing)
    private func normalizePersonCoverageScore(_ coverage: Double) -> Double {
        let optimalCoverageMin = 0.40
        let optimalCoverageMax = 0.60
        
        // If within optimal range, return high score
        if coverage >= optimalCoverageMin && coverage <= optimalCoverageMax {
            return 1.0
        }
        
        // If below optimal, score based on distance from min
        if coverage < optimalCoverageMin {
            let distance = optimalCoverageMin - coverage
            return max(0.0, 1.0 - (distance / optimalCoverageMin))
        }
        
        // If above optimal, score based on distance from max
        let distance = coverage - optimalCoverageMax
        return max(0.0, 1.0 - (distance / (1.0 - optimalCoverageMax)))
    }
    
    
    // Calculate spread score based on overlap
    private func calculateSpreadScore(_ detections: [DetectionResult]) -> Double {
        guard detections.count > 1 else { return 1.0 }
        
        var totalOverlap = 0.0
        var comparisons = 0
        
        for i in 0..<detections.count {
            for j in (i+1)..<detections.count {
                let box1 = detections[i].boundingBox
                let box2 = detections[j].boundingBox
                
                let overlapArea = calculateOverlap(box1, box2)
                let minArea = min(box1.area, box2.area)
                
                if minArea > 0 {
                    totalOverlap += Double(overlapArea / minArea)
                    comparisons += 1
                }
            }
        }
        
        let avgOverlap = comparisons > 0 ? totalOverlap / Double(comparisons) : 0.0
        return max(0.0, 1.0 - avgOverlap) // Lower overlap = higher score
    }
    
    // Calculate overlap between two bounding boxes
    private func calculateOverlap(_ box1: BoundingBox, _ box2: BoundingBox) -> Float {
        let x1 = max(box1.x, box2.x)
        let y1 = max(box1.y, box2.y)
        let x2 = min(box1.x + box1.width, box2.x + box2.width)
        let y2 = min(box1.y + box1.height, box2.y + box2.height)
        
        if x2 < x1 || y2 < y1 {
            return 0.0
        }
        
        return (x2 - x1) * (y2 - y1)
    }
    
    // Normalize furniture coverage to 0-1 score (peak at ~40%)
    private func normalizeCoverageScore(_ coverage: Double) -> Double {
        let optimalCoverage = 0.40
        let distance = abs(coverage - optimalCoverage)
        return max(0.0, 1.0 - (distance / optimalCoverage))
    }
    
    // Calculate composition score based on center proximity
    private func calculateCompositionScore(_ furnitureDetections: [DetectionResult]) -> Double {
        guard !furnitureDetections.isEmpty else { return 0.0 }
        
        let imageCenter = CGPoint(x: 0.5, y: 0.5)
        var totalDistance = 0.0
        
        for detection in furnitureDetections {
            let boxCenterX = CGFloat(detection.boundingBox.x + detection.boundingBox.width / 2)
            let boxCenterY = CGFloat(detection.boundingBox.y + detection.boundingBox.height / 2)
            let boxCenter = CGPoint(x: boxCenterX, y: boxCenterY)
            
            let distance = sqrt(pow(boxCenter.x - imageCenter.x, 2) + pow(boxCenter.y - imageCenter.y, 2))
            totalDistance += distance
        }
        
        let avgDistance = totalDistance / Double(furnitureDetections.count)
        
        // Boost score if average distance is ≤ 0.35
        if avgDistance <= 0.35 {
            return min(1.0, 0.8 + (0.35 - avgDistance)) // Boost score
        }
        
        // Otherwise score based on closeness to center
        return max(0.0, 1.0 - avgDistance)
    }
    
    // Calculate color variance score (optimized with HSV saturation)
    private func calculateColorVariance(_ image: UIImage) -> Double {
        guard let cgImage = image.cgImage else { return 0.0 }
        
        // Downsample to 1/8th size for massive speedup
        let originalSize = CGSize(width: cgImage.width, height: cgImage.height)
        let downsampleSize = CGSize(width: originalSize.width / 8, height: originalSize.height / 8)
        
        guard let downsampledImage = downsampleImage(image, to: downsampleSize) else { return 0.5 }
        guard let downsampledCGImage = downsampledImage.cgImage else { return 0.5 }
        
        // Get pixel data
        guard let pixelData = downsampledCGImage.dataProvider?.data,
              let data = CFDataGetBytePtr(pixelData) else {
            return 0.5
        }
        
        let width = downsampledCGImage.width
        let height = downsampledCGImage.height
        let bytesPerPixel = 4
        let bytesPerRow = downsampledCGImage.bytesPerRow
        
        var saturationSum = 0.0
        var saturationSumSquared = 0.0
        var pixelCount = 0
        
        // Process all pixels and compute saturation variance
        for y in 0..<height {
            for x in 0..<width {
                let offset = y * bytesPerRow + x * bytesPerPixel
                
                let r = Double(data[offset]) / 255.0
                let g = Double(data[offset + 1]) / 255.0
                let b = Double(data[offset + 2]) / 255.0
                
                // Convert RGB to HSV and extract saturation
                let saturation = rgbToSaturation(r: r, g: g, b: b)
                
                saturationSum += saturation
                saturationSumSquared += saturation * saturation
                pixelCount += 1
            }
        }
        
        guard pixelCount > 0 else { return 0.5 }
        
        // Calculate saturation variance
        let mean = saturationSum / Double(pixelCount)
        let variance = (saturationSumSquared / Double(pixelCount)) - (mean * mean)
        let stdDev = sqrt(variance)
        
        // Normalize to 0-1 (higher std dev = more colorful/varied)
        // Saturation std dev typically ranges 0-0.3 for varied images
        let normalizedScore = min(1.0, stdDev / 0.3)
        
        return normalizedScore
    }
    
    // Helper: Convert RGB to Saturation component only
    private func rgbToSaturation(r: Double, g: Double, b: Double) -> Double {
        let maxVal = max(r, g, b)
        let minVal = min(r, g, b)
        
        if maxVal == 0 {
            return 0.0
        }
        
        return (maxVal - minVal) / maxVal
    }
    
    // Helper: Downsample image efficiently
    private func downsampleImage(_ image: UIImage, to size: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        defer { UIGraphicsEndImageContext() }
        
        image.draw(in: CGRect(origin: .zero, size: size))
        return UIGraphicsGetImageFromCurrentImageContext()
    }
}

