//
//  TempCacheHandler.swift
//  HPIkeaSampleApp
//
//  Simple in-memory cache for generated images (per app session)
//

import Foundation
import UIKit



final class TempCacheHandler {
    static let shared = TempCacheHandler()

    private var cache: [TempCacheItem] = []
    private let queue = DispatchQueue(label: "com.hpikea.tempcache", attributes: .concurrent)

    private init() {}

    // MARK: - Legacy API (productUrl-based)

    func getThumbnail(forProductUrl productUrl: String) -> UIImage? {
        getImage(forKey: productUrl)
    }

    func storeThumbnail(_ image: UIImage?, forProductUrl productUrl: String) {
        if let image {
            storeImage(image, forKey: productUrl)
        }
    }

    // MARK: - Generic key-based API (useful for image galleries, etc.)

    func getImage(forKey key: String) -> UIImage? {
        guard !key.isEmpty else { return nil }
        return queue.sync {
            cache.first(where: { $0.productUrl == key })?.thumbnailImg
        }
    }

    func storeImage(_ image: UIImage, forKey key: String) {
        guard !key.isEmpty else { return }
        queue.async(flags: .barrier) {
            if let index = self.cache.firstIndex(where: { $0.productUrl == key }) {
                self.cache[index].thumbnailImg = image
            } else {
                self.cache.append(TempCacheItem(productUrl: key, thumbnailImg: image))
            }
        }
    }

    func clear() {
        queue.async(flags: .barrier) {
            self.cache.removeAll()
        }
    }
}
