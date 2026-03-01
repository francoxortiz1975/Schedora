//
//  MiniTaskManager.swift
//  Schedora
//
//  Centralized manager for mini-task state across the app
//

import Foundation
import SwiftUI
import Combine

// MARK: - Mini Task Manager
@MainActor
class MiniTaskManager: ObservableObject {
    static let shared = MiniTaskManager()
    
    // Dictionary to store mini tasks for each task
    @Published private var miniTasksByTaskId: [UUID: [MiniTask]] = [:]
    
    private init() {}
    
    // Get mini tasks for a task (read-only, won't generate)
    func getMiniTasks(for taskId: UUID) -> [MiniTask] {
        return miniTasksByTaskId[taskId] ?? []
    }
    
    // Initialize mini tasks for a task if not already generated
    func initializeMiniTasks(for taskId: UUID, task: Task) {
        if miniTasksByTaskId[taskId] == nil {
            let generated = generateMiniTasks(for: task)
            miniTasksByTaskId[taskId] = generated
        }
    }
    
    // Update mini task completion status
    func toggleMiniTask(taskId: UUID, miniTaskId: UUID) {
        guard var miniTasks = miniTasksByTaskId[taskId] else { return }
        
        if let index = miniTasks.firstIndex(where: { $0.id == miniTaskId }) {
            miniTasks[index].isCompleted.toggle()
            miniTasksByTaskId[taskId] = miniTasks
        }
    }
    
    // Get completion progress for a task
    func getProgress(for taskId: UUID) -> (completed: Int, total: Int) {
        guard let miniTasks = miniTasksByTaskId[taskId] else { return (0, 0) }
        let completed = miniTasks.filter { $0.isCompleted }.count
        return (completed, miniTasks.count)
    }
    
    // Check if all mini tasks are completed
    func isTaskFullyCompleted(taskId: UUID) -> Bool {
        guard let miniTasks = miniTasksByTaskId[taskId], !miniTasks.isEmpty else { return false }
        return miniTasks.allSatisfy { $0.isCompleted }
    }
    
    // Reset mini tasks for a task
    func resetMiniTasks(for taskId: UUID) {
        miniTasksByTaskId.removeValue(forKey: taskId)
    }
}
