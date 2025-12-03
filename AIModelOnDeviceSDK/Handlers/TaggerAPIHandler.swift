//
//  TaggerAPIHandler.swift
//  AIModelOnDeviceSDK
//
//  Created on 25/11/25.
//

import Foundation
import UIKit

/// Handler for Tagger API calls
public class TaggerAPIHandler {
    
    public static let shared = TaggerAPIHandler()
    
    private let taggerAPIURL = "https://hp.gennoctua.com/api/ml/tagger"
    private let generateRoomAPIURL = "https://hp.gennoctua.com/api/gen/generate-room"
    
    // Dictionary mapping object labels to room categories
    private let objectToRoomMapping: [String: String] = [
        "bed": "bedroom",
        "sofa": "living_room",
        "table": "dining_room"
    ]
    
    // Dictionary mapping room categories to object labels (reverse mapping)
    private let roomToObjectMapping: [String: String] = [
        "bedroom": "bed",
        "living_room": "sofa",
        "dining_room": "table"
    ]
    
    private init() {}
    
    /// Call tagger API with images and their identifiers
    /// - Parameters:
    ///   - imagesWithIDs: Array of images with their identifiers (PHAsset localIdentifier or custom ID)
    ///   - completion: Completion handler with TaggerCompleteResult or error
    public func tagImages(_ imagesWithIDs: [ImageWithID], completion: @escaping (Result<TaggerCompleteResult, Error>) -> Void) {
        guard !imagesWithIDs.isEmpty else {
            completion(.failure(TaggerAPIError.emptyImages))
            return
        }
        
        // Limit to 15 images as per API requirement
        let imagesToProcess = Array(imagesWithIDs.prefix(15))
        
        // Perform image processing on background queue to avoid blocking main thread
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Create multipart form data
            let boundary = UUID().uuidString
            var body = Data()
            
            // Add image files - resize images to reduce upload size and speed
            // Use autoreleasepool to release memory after each image
            var hasError = false
            for (index, imageWithID) in imagesToProcess.enumerated() {
                autoreleasepool {
                    guard !hasError else { return }
                    
                    // Resize image to max 1024px on longest side to reduce upload size
                    let resizedImage = self.resizeImage(imageWithID.image, maxDimension: 1024)
                    
                    // Use lower compression quality for faster upload
                    guard let imageData = resizedImage.jpegData(compressionQuality: 0.7) else {
                        print("❌ Failed to convert image \(index + 1) to JPEG")
                        hasError = true
                        DispatchQueue.main.async {
                            completion(.failure(TaggerAPIError.imageConversionFailed))
                        }
                        return
                    }
                    
                    let filename = "image_\(index + 1).jpg"
                    
                    body.append("--\(boundary)\r\n".data(using: .utf8)!)
                    body.append("Content-Disposition: form-data; name=\"files\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
                    body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
                    body.append(imageData)
                    body.append("\r\n".data(using: .utf8)!)
                    
                    print("✅ Added image \(index + 1): \(filename) (\(imageData.count / 1024)KB)")
                }
                
                guard !hasError else { return }
            }
            
            guard !hasError else { return }
            
            print("📤 Total request body size: \(body.count / 1024)KB")
            
            // Continue with request creation and execution
            self.createAndSendRequest(
                body: body,
                boundary: boundary,
                imagesToProcess: imagesToProcess,
                completion: completion
            )
        }
    }
    
    /// Create and send the API request (called on background queue)
    private func createAndSendRequest(
        body: Data,
        boundary: String,
        imagesToProcess: [ImageWithID],
        completion: @escaping (Result<TaggerCompleteResult, Error>) -> Void
    ) {
        // Make body mutable
        var mutableBody = body
        
        // Add IDs parameter (1, 2, 3, ...)
        let idsString = (1...imagesToProcess.count).map { String($0) }.joined(separator: ", ")
        mutableBody.append("--\(boundary)\r\n".data(using: .utf8)!)
        mutableBody.append("Content-Disposition: form-data; name=\"ids\"\r\n\r\n".data(using: .utf8)!)
        mutableBody.append(idsString.data(using: .utf8)!)
        mutableBody.append("\r\n".data(using: .utf8)!)
        
        mutableBody.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        // Create request
        guard let url = URL(string: taggerAPIURL) else {
            completion(.failure(TaggerAPIError.invalidURL))
            return
        }
        
        // Create URLSessionConfiguration with longer timeout
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 300 // 5 minutes for processing 15 images
        config.timeoutIntervalForResource = 300
        config.waitsForConnectivity = true
        config.allowsCellularAccess = true
        config.httpShouldUsePipelining = false
        config.httpMaximumConnectionsPerHost = 1
        // Reduce network logging noise
        config.urlCache = nil // Disable cache for API calls
        // Use ephemeral session to avoid connection reuse issues
        config.httpShouldSetCookies = false
        config.httpCookieAcceptPolicy = .never
        
        // Create session with dedicated queue to avoid queue conflicts
        let sessionQueue = OperationQueue()
        sessionQueue.name = "com.aimodelondevice.taggerapi"
        sessionQueue.maxConcurrentOperationCount = 1
        let session = URLSession(configuration: config, delegate: nil, delegateQueue: sessionQueue)
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "accept")
        request.setValue("\(mutableBody.count)", forHTTPHeaderField: "Content-Length")
        request.httpBody = mutableBody
        request.timeoutInterval = 300 // 5 minutes
        
        // Create mapping of API ID (1-based index) to image identifier
        let idToIdentifierMap: [Int: String] = Dictionary(uniqueKeysWithValues: 
            imagesToProcess.enumerated().map { (index, imageWithID) in
                (index + 1, imageWithID.identifier)
            }
        )
        
        // Create mapping of identifier to image
        let identifierToImageMap: [String: UIImage] = Dictionary(uniqueKeysWithValues:
            imagesToProcess.map { ($0.identifier, $0.image) }
        )
        
        // Perform request on background queue to avoid blocking
        print("📡 Starting Tagger API request...")
        let startTime = Date()
        
        // Ensure we're on a background queue for the network operation
        let task = session.dataTask(with: request) { [weak self] data, response, error in
            // Ensure completion handler runs on background queue
            let elapsedTime = Date().timeIntervalSince(startTime)
            print("📡 Request completed in \(String(format: "%.2f", elapsedTime)) seconds")
            
            if let error = error {
                let nsError = error as NSError
                print("❌ Tagger API error: \(error.localizedDescription)")
                print("   Error code: \(nsError.code)")
                print("   Error domain: \(nsError.domain)")
                
                // Check for timeout
                DispatchQueue.main.async {
                    if nsError.code == NSURLErrorTimedOut {
                        completion(.failure(TaggerAPIError.timeout))
                    } else {
                        completion(.failure(error))
                    }
                }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    completion(.failure(TaggerAPIError.noData))
                }
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Tagger API: Invalid HTTP response")
                DispatchQueue.main.async {
                    completion(.failure(TaggerAPIError.invalidResponse))
                }
                return
            }
            
            print("📡 Response status: \(httpResponse.statusCode)")
            
            guard (200...299).contains(httpResponse.statusCode) else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                print("❌ Tagger API HTTP Error \(httpResponse.statusCode): \(errorMessage)")
                DispatchQueue.main.async {
                    completion(.failure(TaggerAPIError.httpError(statusCode: httpResponse.statusCode)))
                }
                return
            }
            
            guard !data.isEmpty else {
                print("❌ Tagger API: Empty response data")
                DispatchQueue.main.async {
                    completion(.failure(TaggerAPIError.noData))
                }
                return
            }
            
            print("📡 Response data size: \(data.count) bytes")
            
            // Parse JSON response
            do {
                let decoder = JSONDecoder()
                let taggerResponse = try decoder.decode(TaggerResponse.self, from: data)
                print("✅ Successfully parsed tagger response")
                
                // Map results back to images using identifiers
                var mappedResults: [TaggerResult] = []
                for result in taggerResponse.data {
                    if let identifier = idToIdentifierMap[result.id] {
                        let image = identifierToImageMap[identifier]
                        let taggerResult = TaggerResult(
                            image: image,
                            imageUrl: result.imageUrl,
                            identifier: identifier,
                            taggerResult: result
                        )
                        mappedResults.append(taggerResult)
                    }
                }
                
                // Map best picks to images
                var mappedBestPicks: [BestPickResult] = []
                
                if let livingRoom = taggerResponse.bestPicks.livingRoom,
                   let identifier = idToIdentifierMap[livingRoom.id] {
                    let image = identifierToImageMap[identifier]
                    mappedBestPicks.append(BestPickResult(
                        category: "living_room",
                        image: image,
                        imageUrl: livingRoom.imageUrl,
                        identifier: identifier,
                        bestPick: livingRoom
                    ))
                }
                
                if let dining = taggerResponse.bestPicks.dining,
                   let identifier = idToIdentifierMap[dining.id] {
                    let image = identifierToImageMap[identifier]
                    mappedBestPicks.append(BestPickResult(
                        category: "dining_room", // Map "dining" to "dining_room" for consistency
                        image: image,
                        imageUrl: dining.imageUrl,
                        identifier: identifier,
                        bestPick: dining
                    ))
                }
                
                if let bathroom = taggerResponse.bestPicks.bathroom,
                   let identifier = idToIdentifierMap[bathroom.id] {
                    let image = identifierToImageMap[identifier]
                    mappedBestPicks.append(BestPickResult(
                        category: "bathroom",
                        image: image,
                        imageUrl: bathroom.imageUrl,
                        identifier: identifier,
                        bestPick: bathroom
                    ))
                }
                
                if let kitchen = taggerResponse.bestPicks.kitchen,
                   let identifier = idToIdentifierMap[kitchen.id] {
                    let image = identifierToImageMap[identifier]
                    mappedBestPicks.append(BestPickResult(
                        category: "kitchen",
                        image: image,
                        imageUrl: kitchen.imageUrl,
                        identifier: identifier,
                        bestPick: kitchen
                    ))
                }
                
                if let bedroom = taggerResponse.bestPicks.bedroom,
                   let identifier = idToIdentifierMap[bedroom.id] {
                    let image = identifierToImageMap[identifier]
                    mappedBestPicks.append(BestPickResult(
                        category: "bedroom",
                        image: image,
                        imageUrl: bedroom.imageUrl,
                        identifier: identifier,
                        bestPick: bedroom
                    ))
                }
                
                let completeResult = TaggerCompleteResult(
                    meta: taggerResponse.meta,
                    bestPicks: mappedBestPicks,
                    results: mappedResults
                )
                
                print("✅ Mapped \(mappedResults.count) results and \(mappedBestPicks.count) best picks")
                // Call completion on main queue
                DispatchQueue.main.async {
                    completion(.success(completeResult))
                }
            } catch let decodingError as DecodingError {
                print("❌ JSON Decoding Error: \(decodingError)")
                if let responseString = String(data: data, encoding: .utf8) {
                    print("   Response: \(responseString.prefix(500))")
                }
                DispatchQueue.main.async {
                    completion(.failure(decodingError))
                }
            } catch {
                print("❌ Unexpected error: \(error)")
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
        
        // Resume task - this will start the connection properly
        task.resume()
        
        // Note: URLSession handles connection lifecycle internally
        // The nw_connection warnings are informational and don't affect functionality
    }
    
    /// Generate room images using the generate-room API
    /// - Parameters:
    ///   - taggerResult: The tagger API result containing categorized images
    ///   - objectImages: Dictionary mapping object labels to images ["bed": bedImage, "sofa": sofaImage, "table": tableImage]
    ///   - completion: Completion handler with RoomGenerationCompleteResult or error
    /// Generate room images using the generate-room API
    /// - Parameters:
    ///   - taggerResult: The tagger API result containing categorized images
    ///   - objectImages: Dictionary mapping object labels to images ["bed": bedImage, "sofa": sofaImage, "table": tableImage] (optional, deprecated - use objectUrls instead)
    ///   - objectUrls: Dictionary mapping room types to arrays of object image URLs ["bedroom": [url1, url2], "living_room": [url1, url2]]
    ///   - completion: Completion handler with RoomGenerationCompleteResult or error
    public func generateRooms(
        from taggerResult: TaggerCompleteResult,
        objectImages: [String: UIImage]? = nil,
        objectUrls: [String: [String]]? = nil,
        completion: @escaping (Result<RoomGenerationCompleteResult, Error>) -> Void
    ) {
        // Process on background queue
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            var generationResults: [RoomGenerationResult] = []
            let dispatchGroup = DispatchGroup()
            let resultQueue = DispatchQueue(label: "com.aimodelondevice.roomgeneration", attributes: .concurrent)
            
            // Process best picks - these are the main categories we want to generate
            for bestPick in taggerResult.bestPicks {
                let roomType = bestPick.category
                
                // Get room image - UIImage is required, imageUrl is optional
                guard let roomImage = bestPick.image else {
                    print("⚠️ MISSING room_image for \(roomType): No UIImage available in BestPickResult. The generate-room API requires room_image (multipart form data).")
                    continue
                }
                
                // Get object URLs for this room type
                guard let objectUrlList = objectUrls?[roomType], !objectUrlList.isEmpty else {
                    // Fallback to objectImages if provided (legacy support)
                    if let objectImages = objectImages,
                       let objectLabel = self.roomToObjectMapping[roomType],
                       let objectImage = objectImages[objectLabel] {
                        print("⚠️ MISSING object_url for \(roomType): Using legacy objectImages. Please migrate to objectUrls. The generate-room API requires object_url parameter.")
                        dispatchGroup.enter()
                        self.generateRoom(
                            roomType: roomType,
                            roomImage: roomImage,
                            roomImageUrl: bestPick.imageUrl,
                            objectImage: objectImage
                        ) { result in
                            resultQueue.async(flags: .barrier) {
                                switch result {
                                case .success(let roomResult):
                                    generationResults.append(roomResult)
                                    print("✅ Generated room for \(roomType)")
                                case .failure(let error):
                                    print("❌ Failed to generate room for \(roomType): \(error.localizedDescription)")
                                }
                            }
                            dispatchGroup.leave()
                        }
                        continue
                    }
                    print("⚠️ MISSING object_url for \(roomType): No object URLs found. The generate-room API requires object_url parameter. Please provide product URLs via categoryProductUrls parameter.")
                    continue
                }
                
                // Process each object URL for this room type
                for objectUrl in objectUrlList {
                    dispatchGroup.enter()
                    
                    self.generateRoom(
                        roomType: roomType,
                        roomImage: roomImage,
                        roomImageUrl: bestPick.imageUrl, // Optional, for logging
                        objectUrl: objectUrl
                    ) { result in
                        resultQueue.async(flags: .barrier) {
                            switch result {
                            case .success(let roomResult):
                                generationResults.append(roomResult)
                                print("✅ Generated room for \(roomType) with object \(objectUrl)")
                            case .failure(let error):
                                print("❌ Failed to generate room for \(roomType) with object \(objectUrl): \(error.localizedDescription)")
                            }
                        }
                        dispatchGroup.leave()
                    }
                }
            }
            
            // Wait for all generations to complete
            dispatchGroup.notify(queue: .main) {
                let completeResult = RoomGenerationCompleteResult(results: generationResults)
                completion(.success(completeResult))
            }
        }
    }
    
    /// Generate a single room image using room_image (multipart) and object_url
    private func generateRoom(
        roomType: String,
        roomImage: UIImage,
        roomImageUrl: String? = nil,
        objectUrl: String? = nil,
        objectImage: UIImage? = nil,
        completion: @escaping (Result<RoomGenerationResult, Error>) -> Void
    ) {
        // Validate required parameters
        guard roomImage != nil else {
            completion(.failure(TaggerAPIError.emptyImages))
            return
        }
        
        // object_url is mandatory, objectImage is optional (legacy support)
        guard objectUrl != nil || objectImage != nil else {
            print("❌ MISSING object_url: The generate-room API requires object_url parameter. Please provide product image URL.")
            completion(.failure(TaggerAPIError.emptyImages))
            return
        }
        
        // Use autoreleasepool to manage memory during image processing
        autoreleasepool {
            // Create multipart form data
            let boundary = "Boundary-\(UUID().uuidString)"
            var body = Data()
            
            // Add room_type (mandatory)
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"room_type\"\r\n\r\n".data(using: .utf8)!)
            body.append(roomType.data(using: .utf8)!)
            body.append("\r\n".data(using: .utf8)!)
            
            // Resize room image to reduce upload size and memory usage
            let resizedRoomImage = resizeImage(roomImage, maxDimension: 1024)
            
            // Add room_image (mandatory - multipart form data)
            guard let roomImageData = resizedRoomImage.jpegData(compressionQuality: 0.8) else {
                completion(.failure(TaggerAPIError.imageConversionFailed))
                return
            }
            
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"room_image\"; filename=\"room.jpg\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
            body.append(roomImageData)
            body.append("\r\n".data(using: .utf8)!)
            
            // Add object_url (mandatory)
            if let objectUrl = objectUrl {
                body.append("--\(boundary)\r\n".data(using: .utf8)!)
                body.append("Content-Disposition: form-data; name=\"object_url\"\r\n\r\n".data(using: .utf8)!)
                body.append(objectUrl.data(using: .utf8)!)
                body.append("\r\n".data(using: .utf8)!)
            } else if let objectImage = objectImage {
                // Legacy support: if objectImage is provided, we'd need to upload it
                // But the API requires object_url, so this is deprecated
                print("⚠️ Using objectImage is deprecated. Please provide object_url instead.")
                let resizedObjectImage = resizeImage(objectImage, maxDimension: 1024)
                guard let objectImageData = resizedObjectImage.jpegData(compressionQuality: 0.8) else {
                    completion(.failure(TaggerAPIError.imageConversionFailed))
                    return
                }
                
                let objectFilename: String
                switch roomType {
                case "bedroom":
                    objectFilename = "bed.jpg"
                case "living_room":
                    objectFilename = "sofa.jpg"
                case "dining_room":
                    objectFilename = "table.jpg"
                default:
                    objectFilename = "object.jpg"
                }
                
                body.append("--\(boundary)\r\n".data(using: .utf8)!)
                body.append("Content-Disposition: form-data; name=\"object_image\"; filename=\"\(objectFilename)\"\r\n".data(using: .utf8)!)
                body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
                body.append(objectImageData)
                body.append("\r\n".data(using: .utf8)!)
            }
            
            // Add room_url (optional)
            if let roomImageUrl = roomImageUrl {
                body.append("--\(boundary)\r\n".data(using: .utf8)!)
                body.append("Content-Disposition: form-data; name=\"room_url\"\r\n\r\n".data(using: .utf8)!)
                body.append(roomImageUrl.data(using: .utf8)!)
                body.append("\r\n".data(using: .utf8)!)
            }
            
            body.append("--\(boundary)--\r\n".data(using: .utf8)!)
            
            // Continue with request creation
            self.createRoomGenerationRequest(
                body: body,
                boundary: boundary,
                roomType: roomType,
                roomImage: roomImage,
                roomImageUrl: roomImageUrl,
                objectUrl: objectUrl,
                objectImage: objectImage,
                completion: completion
            )
        }
    }
    
    /// Create and send room generation request
    private func createRoomGenerationRequest(
        body: Data,
        boundary: String,
        roomType: String,
        roomImage: UIImage,
        roomImageUrl: String? = nil,
        objectUrl: String? = nil,
        objectImage: UIImage? = nil,
        completion: @escaping (Result<RoomGenerationResult, Error>) -> Void
    ) {
        
        // Create request
        guard let url = URL(string: generateRoomAPIURL) else {
            completion(.failure(TaggerAPIError.invalidURL))
            return
        }
        
        // Create URLSessionConfiguration with very long timeout for image generation
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 600 // 10 minutes for image generation
        config.timeoutIntervalForResource = 600
        config.waitsForConnectivity = true
        config.allowsCellularAccess = true
        config.httpShouldUsePipelining = false
        config.httpMaximumConnectionsPerHost = 1
        config.urlCache = nil
        config.httpShouldSetCookies = false
        config.httpCookieAcceptPolicy = .never
        
        let sessionQueue = OperationQueue()
        sessionQueue.name = "com.aimodelondevice.roomgeneration"
        sessionQueue.maxConcurrentOperationCount = 1
        let session = URLSession(configuration: config, delegate: nil, delegateQueue: sessionQueue)
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("*/*", forHTTPHeaderField: "accept")
        request.setValue("\(body.count)", forHTTPHeaderField: "Content-Length")
        request.httpBody = body
        request.timeoutInterval = 600 // 10 minutes
        
        print("📡 Generating room for \(roomType)...")
        let startTime = Date()
        
        let task = session.dataTask(with: request) { data, response, error in
            let elapsedTime = Date().timeIntervalSince(startTime)
            print("📡 Room generation completed in \(String(format: "%.2f", elapsedTime)) seconds")
            
            if let error = error {
                let nsError = error as NSError
                print("❌ Room generation error: \(error.localizedDescription)")
                
                DispatchQueue.main.async {
                    if nsError.code == NSURLErrorTimedOut {
                        completion(.failure(TaggerAPIError.timeout))
                    } else {
                        completion(.failure(error))
                    }
                }
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                DispatchQueue.main.async {
                    completion(.failure(TaggerAPIError.invalidResponse))
                }
                return
            }
            
            print("📡 Room generation response status: \(httpResponse.statusCode)")
            
            guard (200...299).contains(httpResponse.statusCode) else {
                let errorMessage = String(data: data ?? Data(), encoding: .utf8) ?? "Unknown error"
                print("❌ Room generation HTTP Error \(httpResponse.statusCode): \(errorMessage)")
                DispatchQueue.main.async {
                    completion(.failure(TaggerAPIError.httpError(statusCode: httpResponse.statusCode)))
                }
                return
            }
            
            guard let data = data, !data.isEmpty else {
                DispatchQueue.main.async {
                    completion(.failure(TaggerAPIError.noData))
                }
                return
            }
            
            // The API returns an image, not JSON
            guard let generatedImage = UIImage(data: data) else {
                print("❌ Failed to create image from response data")
                DispatchQueue.main.async {
                    completion(.failure(TaggerAPIError.imageConversionFailed))
                }
                return
            }
            
            print("✅ Successfully generated room image (\(data.count / 1024)KB)")
            
            let roomResult = RoomGenerationResult(
                category: roomType,
                roomImage: roomImage,
                objectImage: objectImage,
                objectUrl: objectUrl,
                generatedImage: generatedImage,
                roomType: roomType
            )
            
            DispatchQueue.main.async {
                completion(.success(roomResult))
            }
        }
        
        task.resume()
    }

    /// Resize image to reduce upload size
    private func resizeImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let maxSize = max(size.width, size.height)
        
        // If image is already smaller, return original
        if maxSize <= maxDimension {
            return image
        }
        
        // Calculate new size maintaining aspect ratio
        let ratio = maxDimension / maxSize
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        
        // Resize image
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        defer { UIGraphicsEndImageContext() }
        
        image.draw(in: CGRect(origin: .zero, size: newSize))
        return UIGraphicsGetImageFromCurrentImageContext() ?? image
    }
    
    /// Personalizes categories by generating room images
    /// - Parameters:
    ///   - taggerResult: The tagger API result
    ///   - categoryProductUrls: Dictionary mapping category IDs to product URLs
    ///   - categoryRoomTypeMap: Dictionary mapping category IDs to room types
    ///   - completion: Completion handler with categoryId -> generated UIImage mapping
    public func personalizeCategories(
        from taggerResult: TaggerCompleteResult,
        categoryProductUrls: [Int: [String]],
        categoryRoomTypeMap: [Int: String],
        completion: @escaping (Result<[Int: UIImage], Error>) -> Void
    ) {
        // Build objectUrls by room type from categoryProductUrls
        var objectUrls: [String: [String]] = [:]
        var roomTypeToCategoryIds: [String: [Int]] = [:]
        
        for (categoryId, productUrls) in categoryProductUrls {
            guard let roomType = categoryRoomTypeMap[categoryId] else {
                print("⚠️ No room_type mapping for category \(categoryId)")
                continue
            }
            
            if objectUrls[roomType] == nil {
                objectUrls[roomType] = []
                roomTypeToCategoryIds[roomType] = []
            }
            objectUrls[roomType]?.append(contentsOf: productUrls)
            roomTypeToCategoryIds[roomType]?.append(categoryId)
        }
        
        guard !objectUrls.isEmpty else {
            completion(.failure(TaggerAPIError.emptyImages))
            return
        }
        
        print("📦 Personalizing categories with room generation...")
        print("   Room types: \(objectUrls.keys.joined(separator: ", "))")
        for (roomType, urls) in objectUrls {
            print("   \(roomType): \(urls.count) product URLs for \(roomTypeToCategoryIds[roomType]?.count ?? 0) categories")
        }
        
        // Generate rooms
        self.generateRooms(
            from: taggerResult,
            objectUrls: objectUrls
        ) { result in
            switch result {
            case .success(let roomGenerationResult):
                // Map generated images back to category IDs
                var categoryImages: [Int: UIImage] = [:]
                
                // Group results by room type - take first image for each room type
                var roomTypeToFirstImage: [String: UIImage] = [:]
                for roomResult in roomGenerationResult.results {
                    if roomTypeToFirstImage[roomResult.roomType] == nil {
                        roomTypeToFirstImage[roomResult.roomType] = roomResult.generatedImage
                    }
                }
                
                // Assign generated image to each category in that room type
                for (roomType, categoryIds) in roomTypeToCategoryIds {
                    if let generatedImage = roomTypeToFirstImage[roomType] {
                        for categoryId in categoryIds {
                            categoryImages[categoryId] = generatedImage
                        }
                        print("✅ Assigned generated image to \(categoryIds.count) categories for room_type \(roomType)")
                    }
                }
                
                completion(.success(categoryImages))
                
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}

/// Tagger API errors
public enum TaggerAPIError: LocalizedError {
    case emptyImages
    case imageConversionFailed
    case invalidURL
    case noData
    case invalidResponse
    case timeout
    case httpError(statusCode: Int)
    
    public var errorDescription: String? {
        switch self {
        case .emptyImages:
            return "No images provided"
        case .imageConversionFailed:
            return "Failed to convert image to JPEG"
        case .invalidURL:
            return "Invalid API URL"
        case .noData:
            return "No data received from API"
        case .invalidResponse:
            return "Invalid HTTP response"
        case .timeout:
            return "Request timed out. The API may be processing a large number of images. Please try again."
        case .httpError(let statusCode):
            return "HTTP error with status code: \(statusCode)"
        }
    }
}

extension TaggerAPIHandler {
    /// Personalizes products with full tracking, caching, and result object
    /// - Parameters:
    ///   - taggerResult: The tagger API result containing categorized images
    ///   - productUrls: Dictionary mapping product IDs to product image URLs [productId: url]
    ///   - productCategoryMap: Dictionary mapping product IDs to category IDs [productId: categoryId]
    ///   - categoryRoomTypeMap: Dictionary mapping category IDs to room types [categoryId: "bedroom"|"living_room"|"dining_room"]
    ///   - clearCache: Whether to clear cache before generating (default: true)
    ///   - completion: Completion handler with PersonalizationResult containing all mappings and cached images
    public func personalizeProducts(
        from taggerResult: TaggerCompleteResult,
        productUrls: [Int: String],
        productCategoryMap: [Int: Int],
        categoryRoomTypeMap: [Int: String],
        clearCache: Bool = true,
        completion: @escaping (Result<PersonalizationResult, Error>) -> Void
    ) {
        // Clear cache if requested
        if clearCache {
            PersonalizationCache.shared.clear()
        }
        
        // Validate: Check if we have valid bestPicks with room images
        let validBestPicks = taggerResult.bestPicks.filter { $0.image != nil }
        guard !validBestPicks.isEmpty else {
            print("❌ No room images available from tagger result. Clearing model cache and returning empty result.")
            // Clear model cache
            ObjectDetectionModelHandler.shared.clearCache()
            // Return empty result
            let emptyResult = PersonalizationResult(
                productImageMap: [:],
                categoryImageMap: [:],
                requestMap: PersonalizationRequestMap(),
                cachedImages: [:]
            )
            completion(.success(emptyResult))
            return
        }
        
        // Build request map and organize by room type
        var requestMap = PersonalizationRequestMap()
        var roomTypeToProducts: [String: [(productId: Int, categoryId: Int, objectUrl: String)]] = [:]
        
        for (productId, objectUrl) in productUrls {
            guard let categoryId = productCategoryMap[productId],
                  let roomType = categoryRoomTypeMap[categoryId] else {
                print("⚠️ Missing mapping for product \(productId)")
                continue
            }
            
            // Create request tracking object
            let requestId = "product-\(productId)"
            let request = PersonalizationRequest(
                id: requestId,
                productId: productId,
                categoryId: categoryId,
                roomType: roomType,
                objectUrl: objectUrl
            )
            requestMap.addRequest(request)
            
            if roomTypeToProducts[roomType] == nil {
                roomTypeToProducts[roomType] = []
            }
            roomTypeToProducts[roomType]?.append((productId: productId, categoryId: categoryId, objectUrl: objectUrl))
        }
        
        guard !requestMap.getAllRequests().isEmpty else {
            print("❌ No valid products to personalize. Clearing model cache.")
            ObjectDetectionModelHandler.shared.clearCache()
            completion(.failure(TaggerAPIError.emptyImages))
            return
        }
        
        print("📦 Personalizing \(requestMap.count) products...")
        
        // Generate images for all products in parallel
        var productImageMap: [Int: String] = [:]
        var categoryImageMap: [Int: String] = [:]
        var cachedImages: [String: UIImage] = [:]
        let dispatchGroup = DispatchGroup()
        let resultQueue = DispatchQueue(label: "com.aimodelondevice.personalization", attributes: .concurrent)
        
        // Process each room type
        for (roomType, products) in roomTypeToProducts {
            // Find the best pick for this room type
            guard let bestPick = taggerResult.bestPicks.first(where: { $0.category == roomType }),
                  let roomImage = bestPick.image else {
                print("⚠️ No room image available for room_type: \(roomType)")
                continue
            }
            
            // Generate images for each product in this room type
            for product in products {
                dispatchGroup.enter()
                
                let objectUrl = product.objectUrl
                let productId = product.productId
                let categoryId = product.categoryId
                let requestId = "product-\(productId)"
                
                print("   🎨 Generating image for product \(productId) with room_type: \(roomType), objectUrl: \(objectUrl)")
                
                self.generateRoom(
                    roomType: roomType,
                    roomImage: roomImage,
                    roomImageUrl: bestPick.imageUrl,
                    objectUrl: objectUrl
                ) { result in
                    resultQueue.async(flags: .barrier) {
                        switch result {
                        case .success(let roomResult):
                            // Convert to base64 data URL
                            if let imageData = roomResult.generatedImage.jpegData(compressionQuality: 0.9) {
                                let base64String = imageData.base64EncodedString()
                                let dataUrl = "data:image/jpeg;base64," + base64String
                                
                                // Update request with response
                                requestMap.updateRequest(id: requestId, image: roomResult.generatedImage, imageUrl: dataUrl)
                                
                                // Store in cache
                                let cacheKey = "product-\(productId)"
                                PersonalizationCache.shared.storeImage(roomResult.generatedImage, forKey: cacheKey)
                                
                                // Update maps
                                productImageMap[productId] = dataUrl
                                cachedImages[cacheKey] = roomResult.generatedImage
                                
                                // Also update category image map (use first product's image for category)
                                if categoryImageMap[categoryId] == nil {
                                    categoryImageMap[categoryId] = dataUrl
                                    let categoryCacheKey = "category-\(categoryId)"
                                    PersonalizationCache.shared.storeImage(roomResult.generatedImage, forKey: categoryCacheKey)
                                    cachedImages[categoryCacheKey] = roomResult.generatedImage
                                }
                                
                                print("   ✅ Generated and cached image for product \(productId)")
                            }
                        case .failure(let error):
                            print("   ❌ Error generating image for product \(productId): \(error.localizedDescription)")
                        }
                        dispatchGroup.leave()
                    }
                }
            }
        }
        
        // Wait for all generations to complete
        dispatchGroup.notify(queue: .main) {
            // Validate: Check if we got any generated images
            guard !productImageMap.isEmpty || !categoryImageMap.isEmpty else {
                print("❌ No room images generated. No classification or image URLs returned. Clearing model cache and returning empty result.")
                // Clear model cache
                ObjectDetectionModelHandler.shared.clearCache()
                // Clear personalization cache
                PersonalizationCache.shared.clear()
                // Return empty result
                let emptyResult = PersonalizationResult(
                    productImageMap: [:],
                    categoryImageMap: [:],
                    requestMap: requestMap,
                    cachedImages: [:]
                )
                completion(.success(emptyResult))
                return
            }
            
            let result = PersonalizationResult(
                productImageMap: productImageMap,
                categoryImageMap: categoryImageMap,
                requestMap: requestMap,
                cachedImages: cachedImages
            )
            
            print("📦 Personalization complete: \(productImageMap.count) products, \(categoryImageMap.count) categories, \(requestMap.count) requests tracked")
            completion(.success(result))
        }
    }
}

