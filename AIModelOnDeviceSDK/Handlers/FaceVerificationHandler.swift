//
//  FaceVerificationHandler.swift
//  AIModelOnDeviceSDK
//
//  Created on 10/12/25.
//

import Foundation
import UIKit
import Vision

/// Result of face verification process
public struct FaceVerificationResult {
    public let bestImage: UIImage
    public let faceCount: Int
    public let mostFrequentFaceCount: Int
    public let qualityScore: Double
    public let processingTime: Double
    public let allFaceImages: [UIImage] // All images containing the most frequent face
    public let gender: String? // "Men" or "Women"
    public let index: Int // Index of the image in the original list
    
    public init(
        bestImage: UIImage,
        faceCount: Int,
        mostFrequentFaceCount: Int,
        qualityScore: Double,
        processingTime: Double,
        allFaceImages: [UIImage] = [],
        gender: String? = nil,
        index: Int = 0
    ) {
        self.bestImage = bestImage
        self.faceCount = faceCount
        self.mostFrequentFaceCount = mostFrequentFaceCount
        self.qualityScore = qualityScore
        self.processingTime = processingTime
        self.allFaceImages = allFaceImages
        self.gender = gender
        self.index = index
    }
}

/// Face observation with associated image and quality metrics
public struct FaceObservationData {
    /// Original (full) image from the input array
    public let image: UIImage

    /// Cropped face region used to generate the embedding
    public let faceImage: UIImage

    public let observation: VNFaceObservation
    public let imageIndex: Int
    public let qualityScore: Double

    /// 512-D embedding for the face image
    public let embedding: [Float]

    /// "Men" or "Women" (if available)
    public let gender: String?
}

/// Handler for face verification and best image selection
public class FaceVerificationHandler {
    
    public static let shared = FaceVerificationHandler()
    private let faceNetHandler = FaceNetModelHandler.shared
    
    private init() {}

    // MARK: - Clustering / Most-frequent face selection

    /// Returns the best image of the face that appears the most times.
    ///
    /// Logic:
    /// 1) Cluster observations by embedding similarity.
    /// 2) Pick the cluster with the largest size (most frequent face).
    /// 3) Within that cluster, pick the observation with the highest `qualityScore`.
    ///
    /// - Parameters:
    ///   - observations: Face observations (each must have a 512-D embedding)
    ///   - similarityThreshold: Cosine similarity threshold (0..1) to consider two faces the same.
    /// - Returns: The best observation for the most frequent face, plus all observations in that cluster.
    public func bestImageForMostFrequentFace(
        from observations: [FaceObservationData],
        similarityThreshold: Float = 0.80
    ) -> (best: FaceObservationData, all: [FaceObservationData])? {
        let nonEmpty = observations.filter { !$0.embedding.isEmpty }
        guard !nonEmpty.isEmpty else { return nil }

        let clusters = clusterObservations(nonEmpty, similarityThreshold: similarityThreshold)
        guard !clusters.isEmpty else { return nil }

        // Pick the cluster with max count; tie-break by best qualityScore.
        let bestCluster = clusters.max { a, b in
            if a.count != b.count { return a.count < b.count }
            let aBest = a.map(\.qualityScore).max() ?? 0
            let bBest = b.map(\.qualityScore).max() ?? 0
            return aBest < bBest
        }!

        guard let best = bestCluster.max(by: { $0.qualityScore < $1.qualityScore }) else {
            return nil
        }

        return (best: best, all: bestCluster)
    }

    private func clusterObservations(
        _ observations: [FaceObservationData],
        similarityThreshold: Float
    ) -> [[FaceObservationData]] {
        // Greedy single-pass clustering using the first element of a cluster as its representative.
        var clusters: [[FaceObservationData]] = []

        for obs in observations {
            var assignedIndex: Int?

            for (i, cluster) in clusters.enumerated() {
                guard let rep = cluster.first else { continue }
                let similarity = faceNetHandler.calculateSimilarity(
                    embedding1: rep.embedding,
                    embedding2: obs.embedding
                )

                if similarity >= similarityThreshold {
                    assignedIndex = i
                    break
                }
            }

            if let i = assignedIndex {
                clusters[i].append(obs)
            } else {
                clusters.append([obs])
            }
        }

        return clusters
    }
    
    /// Find the best face image from a collection of images
    /// - Parameters:
    ///   - images: Array of images to analyze
    ///   - category: Optional gender filter ("Men" or "Women")
    ///   - completion: Completion handler with FaceVerificationResult
    public func findBestFaceImage(
        _ image: UIImage,
        imageIndex: Int,
        category: String? = nil,
        completion: @escaping (FaceObservationData?) -> Void
    ) {
        if let category = category {
            print("   Filtering for category: \(category)")
        }

        processImageForSingleFace(
            originalImage: image,
            imageIndex: imageIndex,
            category: category,
            completion: completion
        )
    }
    
    /// Filter and return top N face images sorted by quality score
    /// - Parameters:
    ///   - images: Array of images to analyze
    ///   - category: Optional gender filter ("Men" or "Women")
    ///   - maxResults: Maximum number of results to return (default: 15)
    ///   - completion: Completion handler with array of FaceVerificationResult
    public func filterResults(
        _ images: [UIImage],
        category: String? = nil,
        maxResults: Int = 15,
        completion: @escaping ([FaceObservationData]) -> Void
    ) {
        guard !images.isEmpty else {
            completion([])
            return
        }

        print("🔍 Filtering \(images.count) images for best faces...")
        if let category = category {
            print("   Category filter: \(category)")
        }

        let maxConcurrency = 3 // keep memory reasonable
        let dispatchGroup = DispatchGroup()
        let semaphore = DispatchSemaphore(value: maxConcurrency)
        let lock = NSLock()

        var allResults: [FaceObservationData] = []

        DispatchQueue.global(qos: .userInitiated).async {
            for (index, image) in images.enumerated() {
                semaphore.wait()
                dispatchGroup.enter()

                autoreleasepool {
                    self.findBestFaceImage(image, imageIndex: index, category: category) { result in
                        defer {
                            semaphore.signal()
                            dispatchGroup.leave()
                        }

                        guard let result else { return }

                        lock.lock()
                        allResults.append(result)
                        lock.unlock()
                    }
                }
            }

            dispatchGroup.notify(queue: .main) {
                var results = allResults

                // Optional gender filter (if gender is available)
                if let category {
                    results = results.filter { $0.gender == category }
                }

                // Sort by face quality (highest first) and cap to maxResults
                results.sort { $0.qualityScore > $1.qualityScore }
                if maxResults > 0, results.count > maxResults {
                    results = Array(results.prefix(maxResults))
                }

                print("✅ Returning \(results.count) best face images")
                completion(results)
            }
        }
    }
    
    // MARK: - Private Methods
    
    /// Process one image: detect faces, keep only single-face images, and generate 512-D embedding.
    private func processImageForSingleFace(
        originalImage: UIImage,
        imageIndex: Int,
        category: String?,
        completion: @escaping (FaceObservationData?) -> Void
    ) {
        let normalized = normalizeToUpOrientation(originalImage)

        detectFace(in: normalized) { observations in
            // Keep only images with exactly ONE detected face.
            guard let observations, observations.count == 1, let observation = observations.first else {
                completion(nil)
                return
            }

            // Crop face region for embedding.
            guard let faceCrop = self.cropFaceImage(from: normalized, observation: observation) else {
                completion(nil)
                return
            }

            // Generate 512-D embedding (FaceNet if present, else Vision fallback).
            guard let embedding = self.faceNetHandler.getEmbedding(from: faceCrop), embedding.count == 512 else {
                completion(nil)
                return
            }

            let gender = self.faceNetHandler.classifyGender(from: normalized)

            // If a category filter is provided, keep ONLY matches.
            // If gender cannot be determined, skip the image.
            if let category {
                guard gender == category else {
                    completion(nil)
                    return
                }
            }

            let qualityScore = self.calculateFaceQuality(observation: observation, image: normalized)

            let faceData = FaceObservationData(
                image: originalImage,
                faceImage: faceCrop,
                observation: observation,
                imageIndex: imageIndex,
                qualityScore: qualityScore,
                embedding: embedding,
                gender: gender
            )

            completion(faceData)
        }
    }
    
    /// Detect face in a single image
    private func detectFace(
        in image: UIImage,
        completion: @escaping ([VNFaceObservation]?) -> Void
    ) {
        guard let cgImage = image.cgImage else {
            completion(nil)
            return
        }

        let request = VNDetectFaceRectanglesRequest { request, error in
            if let error {
                print("❌ Face detection error: \(error.localizedDescription)")
                completion(nil)
                return
            }

            completion(request.results as? [VNFaceObservation])
        }

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                try handler.perform([request])
            } catch {
                print("❌ Failed to perform face detection: \(error.localizedDescription)")
                completion(nil)
            }
        }
    }

    private func normalizeToUpOrientation(_ image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else { return image }

        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
        defer { UIGraphicsEndImageContext() }

        image.draw(in: CGRect(origin: .zero, size: image.size))
        return UIGraphicsGetImageFromCurrentImageContext() ?? image
    }

    private func cropFaceImage(from image: UIImage, observation: VNFaceObservation) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }

        let imageWidth = CGFloat(cgImage.width)
        let imageHeight = CGFloat(cgImage.height)

        // Vision boundingBox is normalized with origin at bottom-left.
        let bbox = observation.boundingBox
        let x = bbox.minX * imageWidth
        let y = (1.0 - bbox.maxY) * imageHeight
        let width = bbox.width * imageWidth
        let height = bbox.height * imageHeight

        let rect = CGRect(x: x, y: y, width: width, height: height).integral
        guard rect.width > 0, rect.height > 0, let cropped = cgImage.cropping(to: rect) else {
            return nil
        }

        return UIImage(cgImage: cropped, scale: image.scale, orientation: .up)
    }
    
    /// Calculate quality score for a face
    private func calculateFaceQuality(observation: VNFaceObservation, image: UIImage) -> Double {
        var score = 0.0
        
        // 1. Face size score (40% weight) - larger faces are better
        let faceArea = observation.boundingBox.width * observation.boundingBox.height
        let faceSizeScore = min(1.0, Double(faceArea) * 5.0) // Normalize to 0-1
        score += faceSizeScore * 0.4
        
        // 2. Confidence score (30% weight)
        score += Double(observation.confidence) * 0.3
        
        // 3. Position score (20% weight) - centered faces are better
        let centerX = observation.boundingBox.midX
        let centerY = observation.boundingBox.midY
        let distanceFromCenter = sqrt(pow(centerX - 0.5, 2) + pow(centerY - 0.5, 2))
        let positionScore = max(0.0, 1.0 - distanceFromCenter * 2.0)
        score += positionScore * 0.2
        
        // 4. Image sharpness score (10% weight)
        let sharpnessScore = calculateImageSharpness(image, faceBox: observation.boundingBox)
        score += sharpnessScore * 0.1
        
        return score
    }
    
    /// Calculate image sharpness using Laplacian variance
    private func calculateImageSharpness(_ image: UIImage, faceBox: CGRect) -> Double {
        guard let cgImage = image.cgImage else { return 0.5 }
        
        // Convert face bounding box to image coordinates
        let imageWidth = CGFloat(cgImage.width)
        let imageHeight = CGFloat(cgImage.height)
        
        // Vision framework uses bottom-left origin, convert to top-left
        let x = faceBox.minX * imageWidth
        let y = (1.0 - faceBox.maxY) * imageHeight
        var width = faceBox.width * imageWidth
        var height = faceBox.height * imageHeight
        
        let faceRect = CGRect(x: x, y: y, width: width, height: height)
        
        // Crop to face region
        guard let faceCGImage = cgImage.cropping(to: faceRect) else {
            return 0.5
        }
        
        // Calculate variance of Laplacian (simple sharpness metric)
        guard let pixelData = faceCGImage.dataProvider?.data,
              let data = CFDataGetBytePtr(pixelData) else {
            return 0.5
        }
        
        width = CGFloat(faceCGImage.width)
        height = CGFloat(faceCGImage.height)
        let bytesPerRow = faceCGImage.bytesPerRow
        let bytesPerPixel = 4
        
        var laplacianSum = 0.0
        var laplacianSumSquared = 0.0
        var count = 0
        
        // Simple Laplacian kernel: [-1, -1, -1; -1, 8, -1; -1, -1, -1]
        for y in 1..<(Int(height) - 1) {
            for x in 1..<(Int(width) - 1) {
                let offset = y * bytesPerRow + x * bytesPerPixel
                
                // Get grayscale value (use green channel as approximation)
                let center = Double(data[offset + 1])
                
                // Get neighbors
                let top = Double(data[(y - 1) * bytesPerRow + x * bytesPerPixel + 1])
                let bottom = Double(data[(y + 1) * bytesPerRow + x * bytesPerPixel + 1])
                let left = Double(data[y * bytesPerRow + (x - 1) * bytesPerPixel + 1])
                let right = Double(data[y * bytesPerRow + (x + 1) * bytesPerPixel + 1])
                
                // Simplified Laplacian
                let laplacian = abs(4 * center - top - bottom - left - right)
                
                laplacianSum += laplacian
                laplacianSumSquared += laplacian * laplacian
                count += 1
            }
        }
        
        guard count > 0 else { return 0.5 }
        
        // Calculate variance
        let mean = laplacianSum / Double(count)
        let variance = (laplacianSumSquared / Double(count)) - (mean * mean)
        
        // Normalize to 0-1 (typical variance range is 0-10000)
        let normalizedScore = min(1.0, variance / 10000.0)
        
        return normalizedScore
    }
    
    /// Downsample image efficiently
    private func downsampleImage(_ image: UIImage, to size: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        defer { UIGraphicsEndImageContext() }
        
        image.draw(in: CGRect(origin: .zero, size: size))
        return UIGraphicsGetImageFromCurrentImageContext()
    }
}
