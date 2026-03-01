//
//  ProgressRing.swift
//  Schedora
//
//  Circular progress indicator component
//

import SwiftUI

struct ProgressRing: View {
    let progress: Double // 0.0 to 1.0
    let color: Color
    let lineWidth: CGFloat
    let size: CGFloat
    
    init(progress: Double, color: Color = .accentYellow, lineWidth: CGFloat = 8, size: CGFloat = 80) {
        self.progress = progress
        self.color = color
        self.lineWidth = lineWidth
        self.size = size
    }
    
    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(Color.bgSecondary, lineWidth: lineWidth)
            
            // Progress circle
            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.5), value: progress)
            
            // Percentage text
            VStack(spacing: 2) {
                Text("\(Int(progress * 100))")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.textPrimary)
                Text("%")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.textSecondary)
            }
        }
        .frame(width: size, height: size)
    }
}

#Preview {
    ZStack {
        Color.bgPrimary.ignoresSafeArea()
        HStack(spacing: 20) {
            ProgressRing(progress: 0.6, color: .subject1)
            ProgressRing(progress: 0.8, color: .subject2)
            ProgressRing(progress: 0.3, color: .criticalRed)
        }
    }
}
