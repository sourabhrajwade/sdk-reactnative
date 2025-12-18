//
//  SDKCategory.swift
//  HPIkeaSampleApp
//
//  Created by Vinit Chapla on 16/12/25.
//

import Foundation

// MARK: - Category Models
struct SDKVendor {
    let persionalisationType : PersionalisationType
    let arrSDKCategory : [SDKCategory]
}
struct SDKCategory: Identifiable, Hashable {
    let id: Int
    let vendorId: Int
    let name: String
    let displayName: String
    let slug: String
    let categoryUrl: String
    let description: String?
    let imageUrl: String?
    let createdAt: String
    let productCount: Int?
    
    // Custom initializer for creating updated categories
    init(
        id: Int,
        vendorId: Int,
        name: String,
        displayName: String,
        slug: String,
        categoryUrl: String,
        description: String?,
        imageUrl: String?,
        createdAt: String,
        productCount: Int?,
    ) {
        self.id = id
        self.vendorId = vendorId
        self.name = name
        self.displayName = displayName
        self.slug = slug
        self.categoryUrl = categoryUrl
        self.description = description
        self.imageUrl = imageUrl
        self.createdAt = createdAt
        self.productCount = productCount
    }
}
