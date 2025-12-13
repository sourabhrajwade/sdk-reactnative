//
//  FashionGenerationResult.swift
//  HPIkeaSampleApp
//
//  Created by Vinit Chapla on 10/12/25.
//

import Foundation
import UIKit

public struct FashionGenerationResult: Identifiable {
    public let id = UUID()
    public let status: String
    public let result: String // UIImage Base 64  from tagger API
    public let elapsed_time: String // time
    
    public init(status: String, result: String , elapsed_time: String) {
        self.status = status
        self.result = result
        self.elapsed_time = elapsed_time
    }
}
