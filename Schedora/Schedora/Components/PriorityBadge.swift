//
//  PriorityBadge.swift
//  Schedora
//
//  Priority indicator badge (traffic light system)
//

import SwiftUI

struct PriorityBadge: View {
    let priority: Priority
    
    var priorityColor: Color {
        switch priority {
        case .critical:
            return .criticalRed
        case .important:
            return .importantYellow
        case .chill:
            return .chillGreen
        }
    }
    
    var priorityEmoji: String {
        switch priority {
        case .critical:
            return "🔴"
        case .important:
            return "🟡"
        case .chill:
            return "🟢"
        }
    }
    
    var body: some View {
        HStack(spacing: 4) {
            Text(priorityEmoji)
                .font(.system(size: 12))
            Text(priority.rawValue)
                .font(.appCaptionBold)
                .foregroundColor(priorityColor)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(priorityColor.opacity(0.1))
        .cornerRadius(.cornerRadiusSmall)
    }
}

#Preview {
    ZStack {
        Color.bgPrimary.ignoresSafeArea()
        VStack(spacing: 12) {
            PriorityBadge(priority: .critical)
            PriorityBadge(priority: .important)
            PriorityBadge(priority: .chill)
        }
    }
}
