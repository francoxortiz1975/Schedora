//
//  TaskCard.swift
//  Schedora
//
//  Task card component for timeline view
//

import SwiftUI

struct TaskCard: View {
    let task: Task
    @State private var isCompleted: Bool
    var onToggle: ((Bool) -> Void)?
    
    init(task: Task, onToggle: ((Bool) -> Void)? = nil) {
        self.task = task
        self._isCompleted = State(initialValue: task.isCompleted)
        self.onToggle = onToggle
    }
    
    var daysRemainingText: String {
        let days = task.daysRemaining
        if days < 0 {
            return "OVERDUE"
        } else if days == 0 {
            return "TODAY"
        } else if days == 1 {
            return "TOMORROW"
        } else {
            return "\(days) DAYS"
        }
    }
    
    var daysRemainingColor: Color {
        let days = task.daysRemaining
        if days < 0 {
            return .criticalRed
        } else if days <= 3 {
            return .importantYellow
        } else {
            return .chillGreen
        }
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Checkbox
            Button(action: {
                isCompleted.toggle()
                onToggle?(isCompleted)
            }) {
                ZStack {
                    Circle()
                        .stroke(Color(hex: task.subjectColor), lineWidth: 2)
                        .frame(width: 24, height: 24)
                    
                    if isCompleted {
                        Circle()
                            .fill(Color(hex: task.subjectColor))
                            .frame(width: 16, height: 16)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            // Task content
            VStack(alignment: .leading, spacing: 8) {
                // Subject code
                Text(task.subjectCode)
                    .font(.appCaptionBold)
                    .foregroundColor(Color(hex: task.subjectColor))
                    .textCase(.uppercase)
                
                // Task title and type
                HStack(spacing: 8) {
                    Text(task.title)
                        .font(.appBodyBold)
                        .foregroundColor(.textPrimary)
                    
                    Text(task.taskTypeDisplayLabel)
                        .font(.appCaption)
                        .foregroundColor(.textSecondary)
                        .textCase(.uppercase)
                }
                
                // Days remaining
                Text(daysRemainingText)
                    .font(.appCaption)
                    .foregroundColor(daysRemainingColor)
                
                // Priority badge
                PriorityBadge(priority: task.priority)
            }
            
            Spacer()
        }
        .padding(16)
        .background(Color.bgSecondary)
        .cornerRadius(.cornerRadiusMedium)
        .overlay(
            RoundedRectangle(cornerRadius: .cornerRadiusMedium)
                .stroke(Color(hex: task.subjectColor), lineWidth: 2)
        )
        .opacity(isCompleted ? 0.5 : 1.0)
    }
}

#Preview {
    ZStack {
        Color.bgPrimary.ignoresSafeArea()
        VStack(spacing: 16) {
            TaskCard(task: Task(
                title: "Assignment 2",
                taskType: .assignment,
                priority: .important,
                dueDate: Date().addingTimeInterval(15 * 24 * 60 * 60),
                subjectName: "Programming Languages",
                subjectCode: "CSC324",
                subjectColor: "FF6B6B"
            ))
            
            TaskCard(task: Task(
                title: "Midterm Exam",
                taskType: .exam,
                priority: .critical,
                dueDate: Date().addingTimeInterval(3 * 24 * 60 * 60),
                subjectName: "Data Structures",
                subjectCode: "CSC373",
                subjectColor: "4ECDC4",
                isCompleted: true
            ))
        }
        .padding()
    }
}
