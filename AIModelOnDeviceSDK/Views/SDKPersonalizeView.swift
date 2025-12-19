//
//  SDKPersonalizeView.swift
//  HPIkeaSampleApp
//
//  Created by Vinit Chapla on 16/12/25.
//

import SwiftUI

public struct SDKPersonalizeView: View {
    let sdkOptions: SDKOptions
    let onPersionalizationCompletion: (_ strMsg:String) -> Void
    
    
    @StateObject private var viewModel = SDKPersonalizationViewModel()
    @Environment(\.dismiss) private var dismiss
    
    public init(sdkOptions: SDKOptions , onPersionalizationCompletion: @escaping ((String) -> Void)) {
        self.sdkOptions = sdkOptions
        AIModelOnDeviceSDK.shared.sdkOptions = self.sdkOptions
        self.onPersionalizationCompletion = onPersionalizationCompletion
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                if viewModel.isProcessing {
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text(viewModel.currentStep ?? "Processing...")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                } else {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 12) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 60))
                                .foregroundColor(.blue)
                            
                            Text("Personalize Your Experience")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text("We'll analyze your photos to show you personalized furniture recommendations")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .padding(.top, 40)
                        Spacer()
                    }
                }
            }
            .navigationTitle("Personalize")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            Task {
                await viewModel.startPersonalization() { (strMsg) in
                    onPersionalizationCompletion(strMsg)
                    dismiss()
                }
            }
        }
    }
}

