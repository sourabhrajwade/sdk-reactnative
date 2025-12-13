//
//  ImageStorageHandler.swift
//  AIModelOnDeviceSDK
//
//  Created on 10/12/25.
//

import Foundation
import UIKit

/// Handler for saving and fetching UIImage locally
public class ImageStorageHandler {
    
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
    public func saveImage(_ image: UIImage, withName name: String) -> Bool {
        // Create file URL with .png extension
        let fileURL = documentsDirectory.appendingPathComponent("\(name).png")
        
        // Check if file already exists and delete it
        if FileManager.default.fileExists(atPath: fileURL.path) {
            do {
                try FileManager.default.removeItem(at: fileURL)
                print("🗑️ Deleted existing image: \(name).png")
            } catch {
                print("❌ Failed to delete existing image: \(error.localizedDescription)")
                return false
            }
        }
        
        // Convert UIImage to PNG data
        guard let imageData = image.pngData() else {
            print("❌ Failed to convert image to PNG data")
            return false
        }
        
        // Save the image data to file
        do {
            try imageData.write(to: fileURL)
            print("✅ Successfully saved image: \(name).png at \(fileURL.path)")
            return true
        } catch {
            print("❌ Failed to save image: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Fetch a UIImage from local storage
    /// - Parameter name: The name of the image to fetch (without extension)
    /// - Returns: The UIImage if found, nil otherwise
    public func fetchImage(withName name: String) -> UIImage? {
        // Create file URL with .png extension
        let fileURL = documentsDirectory.appendingPathComponent("\(name).png")
        
        // Check if file exists
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("❌ Image not found: \(name).png")
            return nil
        }
        
        // Load image data from file
        guard let imageData = try? Data(contentsOf: fileURL) else {
            print("❌ Failed to load image data for: \(name).png")
            return nil
        }
        
        // Convert data to UIImage
        guard let image = UIImage(data: imageData) else {
            print("❌ Failed to create UIImage from data: \(name).png")
            return nil
        }
        
        print("✅ Successfully fetched image: \(name).png")
        return image
    }
    
    /// Delete an image from local storage
    /// - Parameter name: The name of the image to delete (without extension)
    /// - Returns: True if deletion was successful, false otherwise
    @discardableResult
    public func deleteImage(withName name: String) -> Bool {
        let fileURL = documentsDirectory.appendingPathComponent("\(name).png")
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("⚠️ Image not found for deletion: \(name).png")
            return false
        }
        
        do {
            try FileManager.default.removeItem(at: fileURL)
            print("✅ Successfully deleted image: \(name).png")
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
        let fileURL = documentsDirectory.appendingPathComponent("\(name).png")
        return FileManager.default.fileExists(atPath: fileURL.path)
    }
    
    /// Get the file URL for an image
    /// - Parameter name: The name of the image (without extension)
    /// - Returns: The file URL for the image
    public func getImageURL(withName name: String) -> URL {
        return documentsDirectory.appendingPathComponent("\(name).png")
    }
}
