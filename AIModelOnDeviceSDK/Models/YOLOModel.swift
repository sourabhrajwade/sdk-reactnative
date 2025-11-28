    //
//  YOLOModel.swift
//  AIModelOnDeviceSDK
//
//  Created on 14/11/25.
//

import Foundation

/// YOLO model types supported by the SDK
public enum YOLOModel: String, CaseIterable {
    // YOLO3 variant
    case yolov3 = "yolov3"
    
    public var displayName: String {
        switch self {
        case .yolov3:
            return "YOLOv3"
        }
    }
    
    public var modelDescription: String {
        switch self {
        case .yolov3:
            return "Classic YOLO3 model"
        }
    }
    
    /// Get the file name for the model (handles different naming conventions)
    var modelFileName: String {
        switch self {
        case .yolov3:
            return "YOLOv3"
        }
    }
    
    /// Get the subdirectory path for the model (if in models folder)
    var modelSubdirectory: String? {
        switch self {
        case .yolov3:
            return "models"
        }
    }
}

