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
        thumbnailImg:UIImage,
        roomType: String,
        roomImageUrl: String? = nil,
        objectUrl: String? = nil,
        objectImage: UIImage? = nil,
        completion: @escaping (Result<PersonalisationImageResult, Error>) -> Void
    ) {
        var tagType = ""
        if ["beds", "bed", "bedroom"].contains(roomType) {
            tagType = "bedroom"
        }else if ["sofas", "sofa", "living_room"].contains(roomType) {
            tagType = "living_room"
        }else if ["tables","table", "dining", "dining_room"].contains(roomType){
            tagType = "dining_room"
        }else if ["armchair"].contains(roomType) {
            tagType = "living_room"
        }
        else {
            tagType = "living_room"
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
            let resizedRoomImage = resizeImage(thumbnailImg, maxDimension: 1024)
            
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
                        let persionalisationImageResult = PersonalisationImageResult(productUrl: objectUrl ?? "", resultImage: img)
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
        
        let task = session.dataTask(with: request) { [weak self] data, response, error in
            guard let _ = self else { return }
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
        thumbnailImg:UIImage,
        garmentImageUrl: String,
        productType:String,
        completion: @escaping (Result<PersonalisationImageResult, Error>) -> Void
    ) {
        
        // Use autoreleasepool to manage memory during image processing
        autoreleasepool {
            // Create multipart form data
            // Create multipart form data
            let boundary = "Boundary-\(UUID().uuidString)"
            var body = Data()
            
            // Add room_type (mandatory)
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"garment_image_url\"\r\n\r\n".data(using: .utf8)!)
            body.append((garmentImageUrl).data(using: .utf8)!)
            body.append("\r\n".data(using: .utf8)!)
            
            // Resize room image to reduce upload size and memory usage
            let resizedRoomImage = resizeImage(thumbnailImg, maxDimension: 1024)
            
            // Add room_image (mandatory - multipart form data)
            guard let roomImageData = resizedRoomImage.jpegData(compressionQuality: 0.25) else {
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
                        let persionalisationImageResult = PersonalisationImageResult(productUrl: garmentImageUrl, resultImage: img)
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
        
        let task = session.dataTask(with: request) { [weak self] data, response, error in
            guard let _ = self else { return }
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
