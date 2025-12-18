//
//  ImageStorageHandler.swift
//  AIModelOnDeviceSDK
//
//  Created on 10/12/25.
//

import Foundation
import UIKit

/// Handler for saving and fetching UIImage locally
class ImageStorageHandler {
    
    public static let shared = ImageStorageHandler()
    
    private init() {}
    
    /// Get the documents directory URL
    private var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    /// Save a UIImage to local storage
    /// - Parameters:
    ///   - image: The UIImage to save
    ///   - name: The name to save the image with (without extension)
    /// - Returns: True if save was successful, false otherwise
    
    @discardableResult
    public func saveBestHomeRoomImage(_ image: UIImage, withName name: String) -> Bool {
        
        let urls = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let cacheURL = urls[0].appendingPathComponent("AIModelOnDeviceSDK/BestHomeRoomImages", isDirectory: true)
        
        // Create directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: cacheURL.path) {
            try? FileManager.default.createDirectory(at: cacheURL, withIntermediateDirectories: true)
        }
        
        // Create file URL with .jpg extension
        let fileURL = cacheURL.appendingPathComponent("\(name).jpg")
        
        // Check if file already exists and delete it
        if FileManager.default.fileExists(atPath: fileURL.path) {
            do {
                try FileManager.default.removeItem(at: fileURL)
                print("🗑️ Deleted existing image: \(name).jpg")
            } catch {
                print("❌ Failed to delete existing image: \(error.localizedDescription)")
                return false
            }
        }
        
        // Convert UIImage to PNG data
        guard let imageData = image.jpegData(compressionQuality: 0.8)  else {
            print("❌ Failed to convert image to PNG data")
            return false
        }
        
        // Save the image data to file
        do {
            try imageData.write(to: fileURL)
            print("✅ Successfully saved image: \(name).jpg at \(fileURL.path)")
            return true
        } catch {
            print("❌ Failed to save image: \(error.localizedDescription)")
            return false
        }
    }
    
    @discardableResult
    public func saveBestUserImage(_ image: UIImage, withName name: String) -> Bool {
        
        let urls = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let cacheURL = urls[0].appendingPathComponent("AIModelOnDeviceSDK/BestUserImages", isDirectory: true)
        
        // Create directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: cacheURL.path) {
            try? FileManager.default.createDirectory(at: cacheURL, withIntermediateDirectories: true)
        }
        
        // Create file URL with .jpg extension
        let fileURL = cacheURL.appendingPathComponent("\(name).jpg")
        
        // Check if file already exists and delete it
        if FileManager.default.fileExists(atPath: fileURL.path) {
            do {
                try FileManager.default.removeItem(at: fileURL)
                print("🗑️ Deleted existing image: \(name).jpg")
            } catch {
                print("❌ Failed to delete existing image: \(error.localizedDescription)")
                return false
            }
        }
        
        // Convert UIImage to PNG data
        guard let imageData = image.jpegData(compressionQuality: 0.8)  else {
            print("❌ Failed to convert image to PNG data")
            return false
        }
        
        // Save the image data to file
        do {
            try imageData.write(to: fileURL)
            print("✅ Successfully saved image: \(name).jpg at \(fileURL.path)")
            return true
        } catch {
            print("❌ Failed to save image: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Fetch a UIImage from local storage
    /// - Parameter name: The name of the image to fetch (without extension)
    /// - Returns: The UIImage if found, nil otherwise
    
    public func fetchRoomImage(withName name: String) -> UIImage? {
        // Create file URL with .jpg extension
        let urls = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let cacheURL = urls[0].appendingPathComponent("AIModelOnDeviceSDK/BestHomeRoomImages", isDirectory: true)
        let fileURL = cacheURL.appendingPathComponent("\(name).jpg")
        
        // Check if file exists
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("❌ Image not found: \(name).jpg")
            return nil
        }
        
        // Load image data from file
        guard let imageData = try? Data(contentsOf: fileURL) else {
            print("❌ Failed to load image data for: \(name).jpg")
            return nil
        }
        
        // Convert data to UIImage
        guard let image = UIImage(data: imageData) else {
            print("❌ Failed to create UIImage from data: \(name).jpg")
            return nil
        }
        
        print("✅ Successfully fetched image: \(name).jpg")
        return image
    }
    
    public func fetchUserImage(withName name: String) -> UIImage? {
        // Create file URL with .jpg extension
        let urls = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let cacheURL = urls[0].appendingPathComponent("AIModelOnDeviceSDK/BestUserImages", isDirectory: true)
        let fileURL = cacheURL.appendingPathComponent("\(name).jpg")
        
        // Check if file exists
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("❌ Image not found: \(name).jpg")
            return nil
        }
        
        // Load image data from file
        guard let imageData = try? Data(contentsOf: fileURL) else {
            print("❌ Failed to load image data for: \(name).jpg")
            return nil
        }
        
        // Convert data to UIImage
        guard let image = UIImage(data: imageData) else {
            print("❌ Failed to create UIImage from data: \(name).jpg")
            return nil
        }
        
        print("✅ Successfully fetched image: \(name).jpg")
        return image
    }
    
    /// Delete an image from local storage
    /// - Parameter name: The name of the image to delete (without extension)
    /// - Returns: True if deletion was successful, false otherwise
    @discardableResult
    public func deleteImage(withName name: String) -> Bool {
        let fileURL = documentsDirectory.appendingPathComponent("\(name).jpg")
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("⚠️ Image not found for deletion: \(name).jpg")
            return false
        }
        
        do {
            try FileManager.default.removeItem(at: fileURL)
            print("✅ Successfully deleted image: \(name).jpg")
            return true
        } catch {
            print("❌ Failed to delete image: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Check if an image exists in local storage
    /// - Parameter name: The name of the image to check (without extension)
    /// - Returns: True if the image exists, false otherwise
    public func imageExists(withName name: String) -> Bool {
        let fileURL = documentsDirectory.appendingPathComponent("\(name).jpg")
        return FileManager.default.fileExists(atPath: fileURL.path)
    }
    
    /// Get the file URL for an image
    /// - Parameter name: The name of the image (without extension)
    /// - Returns: The file URL for the image
    public func getImageURL(withName name: String) -> URL {
        return documentsDirectory.appendingPathComponent("\(name).jpg")
    }
    
    func isRoomImagesEmpty() -> Bool {
        // Create file URL with .jpg extension
        let urls = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let cacheURL = urls[0].appendingPathComponent("AIModelOnDeviceSDK/BestHomeRoomImages", isDirectory: true)
        do {
                // Get the contents of the directory (shallow search, does not include subdirectories by default)
                let directoryContents = try FileManager.default.contentsOfDirectory(atPath: cacheURL.path)
                
                // Check if the returned array of contents is empty
                return directoryContents.isEmpty
            } catch {
                // Handle any errors (e.g., bad permissions, directory doesn't exist, etc.)
                print("Error reading directory contents: \(error.localizedDescription)")
                return true // Assuming empty if an error occurs, or handle as needed
            }
    }
    
    func isUserImagesEmpty() -> Bool {
        // Create file URL with .jpg extension
        let urls = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let cacheURL = urls[0].appendingPathComponent("AIModelOnDeviceSDK/BestUserImages", isDirectory: true)
        do {
                // Get the contents of the directory (shallow search, does not include subdirectories by default)
                let directoryContents = try FileManager.default.contentsOfDirectory(atPath: cacheURL.path)
                
                // Check if the returned array of contents is empty
                return directoryContents.isEmpty
            } catch {
                // Handle any errors (e.g., bad permissions, directory doesn't exist, etc.)
                print("Error reading directory contents: \(error.localizedDescription)")
                return true // Assuming empty if an error occurs, or handle as needed
            }
    }
}
