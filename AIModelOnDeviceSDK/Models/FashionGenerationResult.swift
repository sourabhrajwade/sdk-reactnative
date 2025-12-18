//
//  FashionGenerationResult.swift
//  HPIkeaSampleApp
//
//  Created by Vinit Chapla on 10/12/25.
//

import Foundation
import UIKit

public struct PersionalisationImageResult {
    public let productUrl : String
    public let resultImage: UIImage? // UIImage Base 64  from tagger API
    
    public init(productUrl: String, resultImage: UIImage?) {
        self.productUrl = productUrl
        self.resultImage = resultImage
    }
}
