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
    
    // FaceNet model
    case facenet = "facenet"
    
    public var displayName: String {
        switch self {
        case .yolov3:
            return "YOLOv3"
        case .facenet:
            return "FaceNet"
        }
    }
    
    public var modelDescription: String {
        switch self {
        case .yolov3:
            return "Classic YOLO3 model"
        case .facenet:
            return "FaceNet face recognition model"
        }
    }
    
    /// Get the file name for the model (handles different naming conventions)
    var modelFileName: String {
        switch self {
        case .yolov3:
            return "YOLOv3"
        case .facenet:
            return "Facenet"
        }
    }
    
    /// Get the subdirectory path for the model (if in models folder)
    var modelSubdirectory: String? {
        switch self {
        case .yolov3:
            return "models"
        case .facenet:
            return "models"
        }
    }
}

