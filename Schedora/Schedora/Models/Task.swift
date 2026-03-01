//
//  Task.swift
//  Schedora
//
//  Core data model for tasks
//

import Foundation

enum TaskType: String, CaseIterable, Equatable {
    case exam = "EXAM"
    case midterm = "MIDTERM"
    case final = "FINAL"
    case assignment = "ASSIGNMENT"
    case project = "PROJECT"
    case quiz = "QUIZ"
    case reading = "READING"
    case homework = "HOMEWORK"
    case other = "OTHER"
    
    // Days needed for preparation/completion
    var preparationDays: Int {
        switch self {
        case .exam, .midterm, .final:
            return 10  // Exams need 10 days of study
        case .assignment:
            return 5   // Assignments need 5 days
        case .project:
            return 14  // Projects need 2 weeks
        case .quiz:
            return 3   // Quizzes need 3 days
        case .reading:
            return 2   // Readings need 2 days
        case .homework:
            return 4   // Homework needs 4 days
        case .other:
            return 7   // Default 7 days for custom types
        }
    }
}

enum Priority: String, CaseIterable, Equatable {
    case critical = "CRITICAL"
    case important = "IMPORTANT"
    case chill = "CHILL"
    
    var weight: Int {
        switch self {
        case .critical: return 3
        case .important: return 2
        case .chill: return 1
        }
    }
}

struct Task: Identifiable, Equatable {
    let id: UUID
    var title: String
    var taskType: TaskType
    var customTaskLabel: String? // For "OTHER" task type
    var priority: Priority
    var dueDate: Date
    var startDate: Date
    var subjectName: String
    var subjectCode: String
    var subjectColor: String
    var isCompleted: Bool
    var notes: String?

    init(id: UUID = UUID(),
         title: String,
         taskType: TaskType,
         customTaskLabel: String? = nil,
         priority: Priority,
         dueDate: Date,
         startDate: Date? = nil,
         customDuration: Int? = nil,
         subjectName: String,
         subjectCode: String,
         subjectColor: String,
         isCompleted: Bool = false,
         notes: String? = nil) {
        self.id = id
        self.title = title
        self.taskType = taskType
        self.customTaskLabel = customTaskLabel
        self.priority = priority
        self.dueDate = dueDate
        self.subjectName = subjectName
        self.subjectCode = subjectCode
        self.subjectColor = subjectColor
        self.isCompleted = isCompleted
        self.notes = notes

        // If startDate is not provided, calculate it from dueDate and duration
        if let startDate = startDate {
            self.startDate = startDate
        } else {
            let calendar = Calendar.current
            let duration = customDuration ?? taskType.preparationDays
            // Use -(duration - 1) so that durationDays (which adds +1 for inclusive ends) matches the picker value
            self.startDate = calendar.date(byAdding: .day, value: -(duration - 1), to: dueDate) ?? dueDate
        }
    }
    
    // Display label for task type (uses custom label if OTHER)
    var taskTypeDisplayLabel: String {
        if taskType == .other, let customLabel = customTaskLabel, !customLabel.isEmpty {
            return customLabel.uppercased()
        }
        return taskType.rawValue
    }

    // Computed property for days remaining
    var daysRemaining: Int {
        let calendar = Calendar.current
        // Normalize both dates to start of day for accurate day counting
        let today = calendar.startOfDay(for: Date())
        let dueDateNormalized = calendar.startOfDay(for: dueDate)
        let components = calendar.dateComponents([.day], from: today, to: dueDateNormalized)
        return components.day ?? 0
    }

    // Check if task is overdue
    var isOverdue: Bool {
        return dueDate < Date() && !isCompleted
    }

    // Duration in days (from start to due date, inclusive)
    var durationDays: Int {
        let calendar = Calendar.current
        // Normalize both dates to start of day
        let start = calendar.startOfDay(for: startDate)
        let due = calendar.startOfDay(for: dueDate)
        let components = calendar.dateComponents([.day], from: start, to: due)
        // Add 1 because both start and end dates are inclusive
        // e.g., Oct 30 to Oct 31 = 2 days (30th and 31st)
        return max(1, (components.day ?? 0) + 1)
    }

    // Check if task should be started (we're in the preparation window)
    var shouldBeStarted: Bool {
        return Date() >= startDate && Date() <= dueDate
    }
}
