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
    
    private let generateFashionAPIURL = "https://hp.gennoctua.com/api/tryon/virtual-tryon"
    
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
    
    
    /// Generate a single room image using room_image (multipart) and object_url
    public func generateRoom(
        roomType: String,
        roomImageUrl: String? = nil,
        objectUrl: String? = nil,
        objectImage: UIImage? = nil,
        completion: @escaping (Result<PersionalisationImageResult, Error>) -> Void
    ) {
        var tagType = ""
        if ["beds", "bed", "bedroom"].contains(roomType) {
            tagType = "bedroom"
        }else if ["sofas", "sofa", "living_room"].contains(roomType) {
            tagType = "living_room"
        }else if ["tables","armchair" ,"table", "dining", "dining_room"].contains(roomType){
            tagType = "dining_room"
        }else {
            tagType = "living_room"
        }
            
        // Validate required parameters
        guard let roomImage = ImageStorageHandler.shared.fetchRoomImage(withName: tagType) else {
            completion(.failure(TaggerAPIError.emptyImages))
            return
        }
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
            body.append(tagType.data(using: .utf8)!)
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
            
            self.createRoomGenerationRequest(body: body, boundary: boundary) { result in
                switch result {
                case .success(let img):
                    if let img {
                        let persionalisationImageResult = PersionalisationImageResult(productUrl: objectUrl ?? "", resultImage: img)
                        TempCacheHandler.shared.storeThumbnail(img, forProductUrl: objectUrl ?? "")
                        completion(.success(persionalisationImageResult))
                    }else {
                        print("❌ Fashion generation failed:")
                        completion(.failure(TaggerAPIError.emptyImages))
                    }
                case .failure(let error):
                    print("❌ Fashion generation failed: \(error.localizedDescription)")
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// Create and send room generation request
    private func createRoomGenerationRequest(
        body: Data,
        boundary: String,
        completion: @escaping (Result<UIImage?, Error>) -> Void
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
        
        
        let startTime = Date()
        
        let task = session.dataTask(with: request) { data, response, error in
            let elapsedTime = Date().timeIntervalSince(startTime)
            print("📡 Fashion generation completed in \(String(format: "%.2f", elapsedTime)) seconds")
            
            if let error = error {
                let nsError = error as NSError
                print("❌ Fashion generation error: \(error.localizedDescription)")
                
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
            
            print("📡 Fashion generation response status: \(httpResponse.statusCode)")
            
            guard (200...299).contains(httpResponse.statusCode) else {
                let errorMessage = String(data: data ?? Data(), encoding: .utf8) ?? "Unknown error"
                print("❌ Fashion generation HTTP Error \(httpResponse.statusCode): \(errorMessage)")
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
                
                DispatchQueue.main.async {
                    completion(.success(generatedImage))
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
    case jsonDecodingFailed
    
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
        case .jsonDecodingFailed:
            return "Failed to decode API JSON response"
        }
    }
}

extension TaggerAPIHandler {
    
    public func generateFashion(
        garmentImageUrl: String,
        productType:String,
        categorySlug:String,
        completion: @escaping (Result<PersionalisationImageResult, Error>) -> Void
    ) {
        // Validate required parameters
        var imageName = ""
        if categorySlug == "mens_shirts" {
            imageName = "men_face"
        }else if categorySlug == "womens_wear" {
            imageName = "women_face"
        }else {
            imageName = "women_face"
        }
        guard let UserImage = ImageStorageHandler.shared.fetchUserImage(withName: imageName) else {
            completion(.failure(TaggerAPIError.emptyImages))
            return
        }
        
        // Use autoreleasepool to manage memory during image processing
        autoreleasepool {
            // Create multipart form data
            // Create multipart form data
            let boundary = "Boundary-\(UUID().uuidString)"
            var body = Data()
            
            // Add room_type (mandatory)
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"garment_image_url\"\r\n\r\n".data(using: .utf8)!)
            body.append((garmentImageUrl ?? "").data(using: .utf8)!)
            body.append("\r\n".data(using: .utf8)!)
            
            // Resize room image to reduce upload size and memory usage
            let resizedRoomImage = UserImage//resizeImage(UserImage, maxDimension: 1024)
            
            // Add room_image (mandatory - multipart form data)
            guard let roomImageData = resizedRoomImage.jpegData(compressionQuality: 0.8) else {
                completion(.failure(TaggerAPIError.imageConversionFailed))
                return
            }
            
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"user_image\"; filename=\"room.jpg\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
            body.append(roomImageData)
            body.append("\r\n".data(using: .utf8)!)
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"product_type\"\r\n\r\n".data(using: .utf8)!)
            body.append(productType.data(using: .utf8)!)
            body.append("\r\n".data(using: .utf8)!)
            body.append("--\(boundary)--\r\n".data(using: .utf8)!)
            
            // Continue with request creation
            self.createFashionGenerationRequest(body: body, boundary: boundary) { result in
                switch result {
                case .success(let strBase64):
                    if let strBase64 {
                        let img = UIImage.fromBase64DataURL(strBase64)
                        let persionalisationImageResult = PersionalisationImageResult(productUrl: garmentImageUrl, resultImage: img)
                        TempCacheHandler.shared.storeThumbnail(img, forProductUrl: garmentImageUrl)
                        completion(.success(persionalisationImageResult))
                    }else {
                        print("❌ Fashion generation failed:")
                        completion(.failure(TaggerAPIError.emptyImages))
                    }
                case .failure(let error):
                    print("❌ Fashion generation failed: \(error.localizedDescription)")
                    completion(.failure(error))
                }
            }
        }
    }
    private func createFashionGenerationRequest(
        body: Data,
        boundary: String,
        completion: @escaping (Result<String?, Error>) -> Void
    ) {
        
        // Create request
        guard let url = URL(string: generateFashionAPIURL) else {
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
        
        
        let startTime = Date()
        
        let task = session.dataTask(with: request) { data, response, error in
            let elapsedTime = Date().timeIntervalSince(startTime)
            print("📡 Fashion generation completed in \(String(format: "%.2f", elapsedTime)) seconds")
            
            if let error = error {
                let nsError = error as NSError
                print("❌ Fashion generation error: \(error.localizedDescription)")
                
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
            
            print("📡 Fashion generation response status: \(httpResponse.statusCode)")
            
            guard (200...299).contains(httpResponse.statusCode) else {
                let errorMessage = String(data: data ?? Data(), encoding: .utf8) ?? "Unknown error"
                print("❌ Fashion generation HTTP Error \(httpResponse.statusCode): \(errorMessage)")
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
            
            // Parse JSON response into FashionGenerationResult model
            do {
                // Try to decode JSON using JSONSerialization since FashionGenerationResult
                // is a simple struct and the API is expected to return keys:
                // "status", "result" (Base64 image string), and "elapsed_time".
                let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
                guard let json = jsonObject as? [String: Any] else {
                    print("❌ Fashion generation response is not a JSON object")
                    DispatchQueue.main.async {
                        completion(.failure(TaggerAPIError.jsonDecodingFailed))
                    }
                    return
                }
                
                guard
                    let result = json["result"] as? String else {
                    print("❌ Missing required fields in fashion generation response: \(json)")
                    DispatchQueue.main.async {
                        completion(.failure(TaggerAPIError.jsonDecodingFailed))
                    }
                    return
                }
                
                DispatchQueue.main.async {
                    completion(.success(result))
                }
            } catch {
                print("❌ Failed to decode fashion generation JSON: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(.failure(TaggerAPIError.jsonDecodingFailed))
                }
            }
        }
        
        task.resume()
    }
}

extension UIImage {
    /// Supports plain base64 or "data:image/...;base64,xxxx"
    static func fromBase64DataURL(_ input: String) -> UIImage? {
        // Remove whitespace/newlines just in case
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // If it's a data URL, split off the header
        let base64Part: String
        if let commaIndex = trimmed.firstIndex(of: ","),
           trimmed[..<commaIndex].contains("base64") {
            base64Part = String(trimmed[trimmed.index(after: commaIndex)...])
        } else {
            base64Part = trimmed
        }
        
        // Base64 decode -> Data -> UIImage
        guard let data = Data(base64Encoded: base64Part, options: [.ignoreUnknownCharacters]) else {
            return nil
        }
        return UIImage(data: data)
    }
}
