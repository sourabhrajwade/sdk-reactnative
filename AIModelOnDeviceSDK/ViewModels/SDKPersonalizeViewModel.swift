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
        persionalisationType: PersionalisationType,
        onComplete: @escaping (String) -> Void
    ) async {
        isProcessing = true
        errorMessage = nil
        currentStep = "Initializing..."
        do {
            if persionalisationType == .fashion {
                try await fashionPersonalizationService.runPersonalizationPipeline { [weak self] step in
                    Task { @MainActor in
                        self?.currentStep = step
                    }
                }
                onComplete("ersionalization completed.")
            }else {
                try await personalizationService.runPersonalizationPipeline(
                    progressUpdate: { [weak self] step in
                        Task { @MainActor in
                            self?.currentStep = step
                        }
                    }
                )
                onComplete("Persionalization completed.")
            }
            isProcessing = false
        } catch {
            errorMessage = error.localizedDescription
            isProcessing = false
            print("❌ Personalization error: \(error.localizedDescription)")
            //LogWriter.shared.write("❌ Personalization error: \(error.localizedDescription)")
            onComplete("❌ Personalization error: \(error.localizedDescription)")
        }
    }
}

