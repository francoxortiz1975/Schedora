//
//  SubjectProgressCard.swift
//  Schedora
//
//  Subject progress card with ring indicator
//

import SwiftUI

struct SubjectProgressCard: View {
    let subject: Subject
    let isSelected: Bool
    var onTap: (() -> Void)?
    var onLongPress: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 12) {
            // Progress ring
            ProgressRing(
                progress: subject.progressPercentage / 100,
                color: Color(hex: subject.color),
                lineWidth: 6,
                size: 70
            )
            
            // Subject info
            VStack(spacing: 4) {
                Text(subject.code)
                    .font(.appBodyBold)
                    .foregroundColor(.textPrimary)
                    .textCase(.uppercase)
                
                Text("\(subject.completedTasks)/\(subject.totalTasks)")
                    .font(.appCaption)
                    .foregroundColor(.textSecondary)
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 12)
        .background(isSelected ? Color(hex: subject.color).opacity(0.1) : Color.bgSecondary)
        .cornerRadius(.cornerRadiusMedium)
        .overlay(
            RoundedRectangle(cornerRadius: .cornerRadiusMedium)
                .stroke(isSelected ? Color(hex: subject.color) : Color.clear, lineWidth: 2)
        )
        .onTapGesture {
            onTap?()
        }
        .onLongPressGesture(minimumDuration: 0.5) {
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            onLongPress?()
        }
    }
}

#Preview {
    ZStack {
        Color.bgPrimary.ignoresSafeArea()
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                SubjectProgressCard(
                    subject: Subject(
                        name: "Programming Languages",
                        code: "CSC324",
                        color: "FF6B6B",
                        totalTasks: 10,
                        completedTasks: 6
                    ),
                    isSelected: true
                )
                
                SubjectProgressCard(
                    subject: Subject(
                        name: "Data Structures",
                        code: "CSC373",
                        color: "4ECDC4",
                        totalTasks: 8,
                        completedTasks: 5
                    ),
                    isSelected: false
                )
                
                SubjectProgressCard(
                    subject: Subject(
                        name: "All Subjects",
                        code: "ALL",
                        color: "FFE500",
                        totalTasks: 25,
                        completedTasks: 18
                    ),
                    isSelected: false
                )
            }
            .padding()
        }
    }
}
