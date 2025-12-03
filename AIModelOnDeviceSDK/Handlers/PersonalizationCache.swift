//
//  PersonalizationCache.swift
//  AIModelOnDeviceSDK
//
//  Persistent cache for personalized images
//

import Foundation
import UIKit

/// Persistent cache for personalized images in SDK
public class PersonalizationCache {
    public static let shared = PersonalizationCache()
    
    private var memoryCache: [String: UIImage] = [:]
    private let queue = DispatchQueue(label: "com.aimodelondevice.personalizationcache", attributes: .concurrent)
    private let fileManager = FileManager.default
    
    private var cacheDirectory: URL {
        let urls = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        let cacheURL = urls[0].appendingPathComponent("AIModelOnDeviceSDK/PersonalizedImages", isDirectory: true)
        
        // Create directory if it doesn't exist
        if !fileManager.fileExists(atPath: cacheURL.path) {
            try? fileManager.createDirectory(at: cacheURL, withIntermediateDirectories: true)
        }
        
        return cacheURL
    }
    
    private init() {
        // Load existing images from disk on init
        loadFromDisk()
    }
    
    /// Convert image to RGB format (no alpha) to avoid memory waste for opaque images
    private func convertToRGB(_ image: UIImage) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        
        // Check if image already has no alpha
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue)
        
        guard let context = CGContext(
            data: nil,
            width: cgImage.width,
            height: cgImage.height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else { return nil }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))
        
        guard let rgbImage = context.makeImage() else { return nil }
        return UIImage(cgImage: rgbImage, scale: image.scale, orientation: image.imageOrientation)
    }
    
    /// Store an image persistently (both memory and disk)
    public func storeImage(_ image: UIImage, forKey key: String) {
        queue.async(flags: .barrier) {
            // Convert to RGB format (no alpha) to avoid memory waste
            let rgbImage = self.convertToRGB(image) ?? image
            
            // Store in memory
            self.memoryCache[key] = rgbImage
            
            // Store on disk
            let fileURL = self.cacheDirectory.appendingPathComponent("\(key).jpg")
            if let imageData = rgbImage.jpegData(compressionQuality: 0.9) {
                try? imageData.write(to: fileURL)
            }
        }
    }
    
    /// Retrieve an image from cache (memory first, then disk)
    public func getImage(forKey key: String) -> UIImage? {
        return queue.sync {
            // Try memory first
            if let image = memoryCache[key] {
                return image
            }
            
            // Try disk
            let fileURL = cacheDirectory.appendingPathComponent("\(key).jpg")
            if let imageData = try? Data(contentsOf: fileURL),
               let image = UIImage(data: imageData) {
                // Load into memory for faster access next time
                memoryCache[key] = image
                return image
            }
            
            return nil
        }
    }
    
    /// Load all cached images from disk into memory
    private func loadFromDisk() {
        queue.async(flags: .barrier) {
            guard let files = try? self.fileManager.contentsOfDirectory(at: self.cacheDirectory, includingPropertiesForKeys: nil) else {
                return
            }
            
            for fileURL in files where fileURL.pathExtension == "jpg" {
                let key = fileURL.deletingPathExtension().lastPathComponent
                if let imageData = try? Data(contentsOf: fileURL),
                   let image = UIImage(data: imageData) {
                    self.memoryCache[key] = image
                }
            }
        }
    }
    
    /// Clear the cache (both memory and disk)
    public func clear() {
        queue.async(flags: .barrier) {
            self.memoryCache.removeAll()
            
            // Clear disk cache
            if let files = try? self.fileManager.contentsOfDirectory(at: self.cacheDirectory, includingPropertiesForKeys: nil) {
                for fileURL in files {
                    try? self.fileManager.removeItem(at: fileURL)
                }
            }
        }
    }
    
    /// Get all cached images
    public func getAllCachedImages() -> [String: UIImage] {
        return queue.sync {
            return memoryCache
        }
    }
}

