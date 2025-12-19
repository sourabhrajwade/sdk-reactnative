//
//  SDKPersonalizeViewModel.swift
//  HPIkeaSampleApp
//
//  Created by Vinit Chapla on 16/12/25.
//

import Foundation
import Combine
import UIKit
import Photos

@MainActor
final class SDKPersonalizationViewModel: ObservableObject {
    @Published var isProcessing = false
    @Published var currentStep: String?
    @Published var errorMessage: String?
    
    private let personalizationService = SDKPersonalizationService.shared
    private let fashionPersonalizationService = FashionPersonalizationService.shared
    
    func startPersonalization(
        onComplete: @escaping (String) -> Void
    ) async {
        isProcessing = true
        errorMessage = nil
        currentStep = "Initializing..."
        let sdkOptions = AIModelOnDeviceSDK.shared.sdkOptions
        do {
            switch sdkOptions.persionalisationType {
            case.all :
                try await fashionPersonalizationService.runPersonalizationPipeline { [weak self] step in
                    Task { @MainActor in
                        self?.currentStep = step
                    }
                }
                Task { @MainActor in
                    self.currentStep = "Fashion Persionalization completed."
                }
                try await personalizationService.runPersonalizationPipeline(
                    progressUpdate: { [weak self] step in
                        Task { @MainActor in
                            self?.currentStep = step
                        }
                    }
                )
                isProcessing = false
                onComplete("Homegoods Persionalization completed.")
            case .homegoods:
                try await personalizationService.runPersonalizationPipeline(
                    progressUpdate: { [weak self] step in
                        Task { @MainActor in
                            self?.currentStep = step
                        }
                    }
                )
                isProcessing = false
                onComplete("Homegoods Persionalization completed.")
            case .fashion:
                try await fashionPersonalizationService.runPersonalizationPipeline { [weak self] step in
                    Task { @MainActor in
                        self?.currentStep = step
                    }
                }
                isProcessing = false
                onComplete("Fashion Persionalization completed.")
            case .unKnown:
                isProcessing = false
                onComplete("Fashion Persionalization completed.")
                break
            }
        } catch {
            errorMessage = error.localizedDescription
            isProcessing = false
            print("❌ Personalization error: \(error.localizedDescription)")
            //LogWriter.shared.write("❌ Personalization error: \(error.localizedDescription)")
            onComplete("❌ Personalization error: \(error.localizedDescription)")
        }
    }
}

