//
//  PersonalizationLoadingView.swift
//  Nurtra V2
//
//  Created by AI Assistant on 11/6/25.
//

import SwiftUI

struct PersonalizationLoadingView: View {
    let progress: Double // 0.0 to 1.0
    let completedCount: Int
    let totalCount: Int
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Title
            Text("Personalizing your experience")
                .font(.title2)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
            
            // Progress Bar Container
            VStack(spacing: 16) {
                // Progress Bar
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray5))
                        .frame(height: 24)
                    
                    // Progress Fill
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.blue,
                                    Color.blue.opacity(0.8)
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(24, UIScreen.main.bounds.width * 0.7 * progress), height: 24)
                        .animation(.easeInOut(duration: 0.3), value: progress)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 24)
                
                // Percentage Text
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(.blue)
                    .monospacedDigit()
            }
            .padding(.horizontal, 40)
            
            Spacer()
            
            // Loading Indicator
            ProgressView()
                .scaleEffect(1.5)
                .padding(.bottom, 60)
        }
        .padding()
    }
}

#Preview {
    PersonalizationLoadingView(progress: 0.6, completedCount: 6, totalCount: 10)
}

