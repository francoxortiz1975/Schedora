//
//  TaskManager.swift
//  Schedora
//
//  Centralized task management for app-wide state
//

import SwiftUI
import Combine

class TaskManager: ObservableObject {
    @Published var tasks: [Task]

    init(tasks: [Task] = mockTasks) {
        self.tasks = tasks
    }

    // Update task completion status
    func toggleTaskCompletion(_ task: Task, isCompleted: Bool) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index].isCompleted = isCompleted
        }
    }

    // Update task duration (start and due dates)
    func updateTaskDuration(_ task: Task, newStartDate: Date, newDueDate: Date) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            print("📅 TaskManager: Updating task '\(task.title)'")
            print("   Old dates: \(formatter.string(from: tasks[index].startDate)) to \(formatter.string(from: tasks[index].dueDate))")
            print("   New dates: \(formatter.string(from: newStartDate)) to \(formatter.string(from: newDueDate))")

            tasks[index].startDate = newStartDate
            tasks[index].dueDate = newDueDate

            // Verify the update
            print("   Saved dates: \(formatter.string(from: tasks[index].startDate)) to \(formatter.string(from: tasks[index].dueDate))")
        }
    }

    // Add new tasks
    func addTasks(_ newTasks: [Task]) {
        tasks.append(contentsOf: newTasks)
    }

    // Add single task
    func addTask(_ task: Task) {
        tasks.append(task)
    }

    // Remove task
    func removeTask(_ task: Task) {
        tasks.removeAll(where: { $0.id == task.id })
    }

    // Remove all tasks belonging to a subject
    func removeTasksForSubject(_ subjectCode: String) {
        tasks.removeAll(where: { $0.subjectCode == subjectCode })
    }

    // Update existing task
    func updateTask(_ task: Task) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index] = task
        }
    }
}
