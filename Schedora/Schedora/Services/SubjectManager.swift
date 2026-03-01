//
//  SubjectManager.swift
//  Schedora
//
//  Manages subjects with add, edit, delete functionality
//

import Foundation
import SwiftUI
import Combine

@MainActor
class SubjectManager: ObservableObject {
    @Published var subjects: [Subject] = []
    
    init() {
        loadSubjects()
    }
    
    private func loadSubjects() {
        // Load from mockSubjects initially
        subjects = mockSubjects
    }
    
    // MARK: - CRUD Operations
    
    func addSubject(name: String, code: String, color: String) {
        let newSubject = Subject(
            name: name,
            code: code.uppercased(),
            color: color,
            totalTasks: 0,
            completedTasks: 0
        )
        subjects.append(newSubject)
        syncToMockData()
    }
    
    func updateSubject(_ subject: Subject, name: String, code: String, color: String) {
        if let index = subjects.firstIndex(where: { $0.id == subject.id }) {
            subjects[index].name = name
            subjects[index].code = code.uppercased()
            subjects[index].color = color
            syncToMockData()
        }
    }
    
    func deleteSubject(_ subject: Subject, taskManager: TaskManager? = nil) {
        // Don't allow deleting "ALL"
        guard subject.code != "ALL" else { return }
        // Always remove all tasks belonging to this subject first
        taskManager?.removeTasksForSubject(subject.code)
        subjects.removeAll { $0.id == subject.id }
        syncToMockData()
    }
    
    private func syncToMockData() {
        // Keep mockSubjects in sync for other views
        mockSubjects = subjects
    }
    
    // MARK: - Statistics
    
    func updateSubjectStats(for tasks: [Task]) {
        for index in subjects.indices {
            if subjects[index].code == "ALL" {
                subjects[index].totalTasks = tasks.count
                subjects[index].completedTasks = tasks.filter { $0.isCompleted }.count
            } else {
                let subjectTasks = tasks.filter { $0.subjectCode == subjects[index].code }
                subjects[index].totalTasks = subjectTasks.count
                subjects[index].completedTasks = subjectTasks.filter { $0.isCompleted }.count
            }
        }
        syncToMockData()
    }
}

// MARK: - Available Colors for Subjects
let subjectColorOptions: [String] = [
    "FF6B6B", // Coral Red
    "4ECDC4", // Teal
    "FFE66D", // Yellow
    "95E1D3", // Mint
    "F38181", // Pink
    "AA96DA", // Lavender
    "FCBAD3", // Light Pink
    "A8D8EA", // Light Blue
    "FF9F43", // Orange
    "6C5CE7", // Purple
    "00B894", // Green
    "E17055", // Burnt Orange
]
