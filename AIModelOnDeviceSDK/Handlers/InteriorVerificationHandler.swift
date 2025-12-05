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
public class InteriorVerificationHandler {
    
    public static let shared = InteriorVerificationHandler()
    
    // Furniture categories (COCO dataset)
    private let furnitureCategories: Set<String> = [
        "chair", "couch", "bed", "dining table", "desk",
        "refrigerator", "sofa",
        "table", "ottoman"
    ]
    
    // Categories to exclude from verification calculations (but still show in detection results)
    private let excludedCategories: Set<String> = [
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
    
    private init() {}
    
    /// Verify if an image is a valid interior image
    /// - Parameters:
    ///   - image: The image to verify
    ///   - modelType: The YOLO model to use for object detection
    ///   - completion: Completion handler with VerificationResult
    public func verifyInteriorImage(_ image: UIImage, using modelType: YOLOModel, completion: @escaping (VerificationResult) -> Void) {
        let totalStartTime = CFAbsoluteTimeGetCurrent()
        var result = VerificationResult()
        var filterResults: [FilterResult] = []
        
        // Step 1: Detect objects
        let detectionStart = CFAbsoluteTimeGetCurrent()
        ObjectDetectionModelHandler.shared.detectObjects(image, using: modelType) { detections, latency in
            guard let detections = detections else {
                result.filterResults = [FilterResult(
                    name: "Object Detection",
                    passed: false,
                    message: "Failed to detect objects",
                    value: "Error",
                    latency: 0.0
                )]
                completion(result)
                return
            }
            
            let detectionLatency = (CFAbsoluteTimeGetCurrent() - detectionStart) * 1000
            result.detections = detections // Keep original detections for display
            
            // Filter out excluded categories for verification calculations
            let relevantDetections = detections.filter { detection in
                !self.excludedCategories.contains(detection.label.lowercased())
            }
            
            // Log all detected objects with their names and confidence scores
            print("🔍 Detected \(detections.count) object(s):")
            for detection in detections {
                print("   - \(detection.label): \(String(format: "%.1f%%", detection.confidence * 100)) confidence")
            }
            
            // Log excluded items
            let excludedItems = detections.filter { self.excludedCategories.contains($0.label.lowercased()) }
            if !excludedItems.isEmpty {
                print("🚫 Excluded \(excludedItems.count) item(s) from verification calculations:")
                for item in excludedItems {
                    print("   - \(item.label): \(String(format: "%.1f%%", item.confidence * 100)) confidence")
                }
            }
            
            // Step 2: Confidence Score Filter (using relevant detections only)
            let confidenceStart = CFAbsoluteTimeGetCurrent()
            let highConfidenceDetections = relevantDetections.filter { $0.confidence > 0.6 }
            let hasHighConfidenceObject = !highConfidenceDetections.isEmpty
            let confidenceLatency = (CFAbsoluteTimeGetCurrent() - confidenceStart) * 1000
            
            if !hasHighConfidenceObject {
                print("❌ No relevant objects with confidence > 60% found")
                // Format relevant detected object labels for display (excluding filtered items)
                let detectedLabels = relevantDetections.map { "\($0.label) (\(String(format: "%.0f%%", $0.confidence * 100)))" }
                let labelsString = detectedLabels.isEmpty ? "None" : detectedLabels.joined(separator: ", ")
                filterResults.append(FilterResult(
                    name: "Object Confidence",
                    passed: false,
                    message: "No objects detected with confidence > 60%",
                    value: labelsString,
                    latency: confidenceLatency
                ))
                result.filterResults = filterResults
                result.totalLatency = (CFAbsoluteTimeGetCurrent() - totalStartTime) * 1000
                completion(result)
                return
            }
            
            // Log high confidence objects
            print("✅ Found \(highConfidenceDetections.count) relevant object(s) with confidence > 60%:")
            for detection in highConfidenceDetections {
                print("   - \(detection.label): \(String(format: "%.1f%%", detection.confidence * 100)) confidence")
            }
            
            // Format high confidence object labels for display
            let highConfidenceLabels = highConfidenceDetections.map { "\($0.label) (\(String(format: "%.0f%%", $0.confidence * 100)))" }
            let labelsString = highConfidenceLabels.joined(separator: ", ")
            filterResults.append(FilterResult(
                name: "Object Confidence",
                passed: true,
                message: "High confidence objects detected",
                value: labelsString,
                latency: confidenceLatency
            ))
            
            // Step 3: Check for person or furniture (using relevant detections only)
            let checkStart = CFAbsoluteTimeGetCurrent()
            let personDetections = relevantDetections.filter { $0.label.lowercased() == "person" }
            let furnitureDetections = relevantDetections.filter { self.furnitureCategories.contains($0.label.lowercased()) }
            let checkLatency = (CFAbsoluteTimeGetCurrent() - checkStart) * 1000
            
            if personDetections.isEmpty && furnitureDetections.isEmpty {
                filterResults.append(FilterResult(
                    name: "Room Detection",
                    passed: false,
                    message: "Not a room image",
                    value: "No person or furniture detected",
                    latency: checkLatency
                ))
                result.filterResults = filterResults
                result.totalLatency = (CFAbsoluteTimeGetCurrent() - totalStartTime) * 1000
                completion(result)
                return
            }
            
            filterResults.append(FilterResult(
                name: "Room Detection",
                passed: true,
                message: "Room image detected",
                value: "\(personDetections.count) person(s), \(furnitureDetections.count) furniture",
                latency: checkLatency
            ))
            
            // Step 4: Person Coverage Filter
            let personCoverageStart = CFAbsoluteTimeGetCurrent()
            let totalPersonCoverage = personDetections.reduce(0.0) { $0 + Double($1.areaPercentage) }
            let personCoverageLatency = (CFAbsoluteTimeGetCurrent() - personCoverageStart) * 1000
            
            if totalPersonCoverage > 0.20 {
                filterResults.append(FilterResult(
                    name: "Person Coverage",
                    passed: false,
                    message: "Too much person coverage (> 20%)",
                    value: String(format: "%.1f%%", totalPersonCoverage * 100),
                    latency: personCoverageLatency
                ))
                result.filterResults = filterResults
                result.totalLatency = (CFAbsoluteTimeGetCurrent() - totalStartTime) * 1000
                completion(result)
                return
            }
            
            filterResults.append(FilterResult(
                name: "Person Coverage",
                passed: true,
                message: "Acceptable person coverage (≤ 30%)",
                value: String(format: "%.1f%%", totalPersonCoverage * 100),
                latency: personCoverageLatency
            ))
            
            // Step 5: Furniture Coverage Filter
            let furnitureCoverageStart = CFAbsoluteTimeGetCurrent()
            let totalFurnitureCoverage = furnitureDetections.reduce(0.0) { $0 + Double($1.areaPercentage) }
            let furnitureCoverageLatency = (CFAbsoluteTimeGetCurrent() - furnitureCoverageStart) * 1000
            
            if totalFurnitureCoverage < 0.03 {
                filterResults.append(FilterResult(
                    name: "Furniture Coverage",
                    passed: false,
                    message: "Too little furniture (< 3%) - objects too far/small",
                    value: String(format: "%.1f%%", totalFurnitureCoverage * 100),
                    latency: furnitureCoverageLatency
                ))
                result.filterResults = filterResults
                result.totalLatency = (CFAbsoluteTimeGetCurrent() - totalStartTime) * 1000
                completion(result)
                return
            }
            
            if totalFurnitureCoverage > 0.85 {
                filterResults.append(FilterResult(
                    name: "Furniture Coverage",
                    passed: false,
                    message: "Too much furniture (> 85%) - objects too close/zoomed",
                    value: String(format: "%.1f%%", totalFurnitureCoverage * 100),
                    latency: furnitureCoverageLatency
                ))
                result.filterResults = filterResults
                result.totalLatency = (CFAbsoluteTimeGetCurrent() - totalStartTime) * 1000
                completion(result)
                return
            }
            
            filterResults.append(FilterResult(
                name: "Furniture Coverage",
                passed: true,
                message: "Good furniture coverage (3-85%)",
                value: String(format: "%.1f%%", totalFurnitureCoverage * 100),
                latency: furnitureCoverageLatency
            ))
            
            // Step 6: Object Spread Filter
            let spreadStart = CFAbsoluteTimeGetCurrent()
            let spreadScore = self.calculateSpreadScore(furnitureDetections)
            let spreadLatency = (CFAbsoluteTimeGetCurrent() - spreadStart) * 1000
            
            if spreadScore < 0.03 {
                filterResults.append(FilterResult(
                    name: "Object Spread",
                    passed: false,
                    message: "Furniture is too clumped together",
                    value: String(format: "Score: %.2f (< 0.03)", spreadScore),
                    latency: spreadLatency
                ))
                result.filterResults = filterResults
                result.totalLatency = (CFAbsoluteTimeGetCurrent() - totalStartTime) * 1000
                completion(result)
                return
            }
            
            filterResults.append(FilterResult(
                name: "Object Spread",
                passed: true,
                message: "Good furniture distribution",
                value: String(format: "Score: %.2f", spreadScore),
                latency: spreadLatency
            ))
            
            // Step 7: Clutter Filter
            let clutterStart = CFAbsoluteTimeGetCurrent()
            let furnitureCount = furnitureDetections.count
            let clutterLatency = (CFAbsoluteTimeGetCurrent() - clutterStart) * 1000
            
            if furnitureCount > 25 {
                filterResults.append(FilterResult(
                    name: "Clutter Filter",
                    passed: false,
                    message: "Too many furniture objects detected (> 25)",
                    value: "\(furnitureCount) objects",
                    latency: clutterLatency
                ))
                result.filterResults = filterResults
                result.totalLatency = (CFAbsoluteTimeGetCurrent() - totalStartTime) * 1000
                completion(result)
                return
            }
            
            filterResults.append(FilterResult(
                name: "Clutter Filter",
                passed: true,
                message: "Acceptable number of furniture objects",
                value: "\(furnitureCount) objects",
                latency: clutterLatency
            ))
            
            // Step 8: Aspect Ratio Filter
            let aspectStart = CFAbsoluteTimeGetCurrent()
            let aspectRatio = Double(image.size.width) / Double(image.size.height)
            let aspectLatency = (CFAbsoluteTimeGetCurrent() - aspectStart) * 1000
            
            if aspectRatio < 0.5 || aspectRatio > 2.0 {
                let orientation = aspectRatio < 0.5 ? "too tall" : "too wide"
                filterResults.append(FilterResult(
                    name: "Aspect Ratio",
                    passed: false,
                    message: "Image aspect ratio is \(orientation)",
                    value: String(format: "%.2f (valid: 0.5-2.0)", aspectRatio),
                    latency: aspectLatency
                ))
                result.filterResults = filterResults
                result.totalLatency = (CFAbsoluteTimeGetCurrent() - totalStartTime) * 1000
                completion(result)
                return
            }
            
            filterResults.append(FilterResult(
                name: "Aspect Ratio",
                passed: true,
                message: "Good aspect ratio",
                value: String(format: "%.2f", aspectRatio),
                latency: aspectLatency
            ))
            
            // Step 9: Color Variance Filter
            let colorStart = CFAbsoluteTimeGetCurrent()
            let colorScore = self.calculateColorVariance(image)
            let colorLatency = (CFAbsoluteTimeGetCurrent() - colorStart) * 1000
            
            if colorScore < 0.015 {
                filterResults.append(FilterResult(
                    name: "Color Variance",
                    passed: false,
                    message: "Image is too dull/gray or has poor lighting",
                    value: String(format: "Score: %.3f (< 0.015)", colorScore),
                    latency: colorLatency
                ))
                result.filterResults = filterResults
                result.totalLatency = (CFAbsoluteTimeGetCurrent() - totalStartTime) * 1000
                completion(result)
                return
            }
            
            filterResults.append(FilterResult(
                name: "Color Variance",
                passed: true,
                message: "Good color variance and lighting",
                value: String(format: "Score: %.2f", colorScore),
                latency: colorLatency
            ))
            
            // Step 10: Composition (Center Proximity)
            let compositionStart = CFAbsoluteTimeGetCurrent()
            let compositionScore = self.calculateCompositionScore(furnitureDetections)
            let compositionLatency = (CFAbsoluteTimeGetCurrent() - compositionStart) * 1000
            
            filterResults.append(FilterResult(
                name: "Composition",
                passed: true,
                message: "Furniture center proximity evaluated",
                value: String(format: "Score: %.2f", compositionScore),
                latency: compositionLatency
            ))
            
            // Calculate Final Score
            let furnitureCoverageScore = self.normalizeCoverageScore(totalFurnitureCoverage)
            
            let scoreBreakdown = ScoreBreakdown(
                furnitureCoverageScore: furnitureCoverageScore,
                spreadScore: spreadScore,
                compositionScore: compositionScore,
                colorScore: colorScore,
                finalScore: 0.4 * furnitureCoverageScore +
                           0.25 * spreadScore +
                           0.25 * compositionScore +
                           0.10 * colorScore
            )
            
            result.isValid = true
            result.score = scoreBreakdown.finalScore
            result.filterResults = filterResults
            result.scoreBreakdown = scoreBreakdown
            result.totalLatency = (CFAbsoluteTimeGetCurrent() - totalStartTime) * 1000
            
            completion(result)
        }
    }
    
    /// Filter and return top 15 images sorted by highest score from scoreBreakdown
    /// - Parameters:
    ///   - images: Array of images to verify and filter
    ///   - modelType: The YOLO model to use for object detection
    ///   - completion: Completion handler with top 15 ImageVerificationResult sorted by score (highest first)
    public func filterResults(_ images: [UIImage], using modelType: YOLOModel, completion: @escaping ([ImageVerificationResult]) -> Void) {
        guard !images.isEmpty else {
            completion([])
            return
        }
        
        let maxResults = 15
        let batchSize = 3 // Process 3 images at a time to manage memory
        var allResults: [ImageVerificationResult] = []
        let resultQueue = DispatchQueue(label: "com.aimodelondevice.filterResults", attributes: .concurrent)
        let dispatchGroup = DispatchGroup()
        
        // Process images in batches to manage memory
        DispatchQueue.global(qos: .userInitiated).async {
            let semaphore = DispatchSemaphore(value: batchSize) // Limit concurrent operations
            
            for (index, image) in images.enumerated() {
                // Wait if we've reached the batch limit
                semaphore.wait()
                
                dispatchGroup.enter()
                
                // Use autoreleasepool to release memory after each image
                autoreleasepool {
                    self.verifyInteriorImage(image, using: modelType) { result in
                        defer {
                            semaphore.signal() // Signal when done
                            dispatchGroup.leave()
                        }
                        
                        // Only include valid results with scoreBreakdown
                        if result.isValid, let scoreBreakdown = result.scoreBreakdown {
                            let imageResult = ImageVerificationResult(
                                image: image,
                                result: result,
                                index: index
                            )
                            
                            resultQueue.async(flags: .barrier) {
                                allResults.append(imageResult)
                            }
                        }
                    }
                }
            }
            
            // Wait for all verifications to complete
            dispatchGroup.notify(queue: .main) {
                // Sort by scoreBreakdown.finalScore (highest first)
                let sortedResults = allResults.sorted { first, second in
                    let firstScore = first.result.scoreBreakdown?.finalScore ?? 0.0
                    let secondScore = second.result.scoreBreakdown?.finalScore ?? 0.0
                    return firstScore > secondScore
                }
                
                // Return top 15
                let topResults = Array(sortedResults.prefix(maxResults))
                completion(topResults)
            }
        }
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

