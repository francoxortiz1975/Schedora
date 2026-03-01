//
//  Subject.swift
//  Schedora
//
//  Subject model for organizing tasks
//

import Foundation

struct Subject: Identifiable {
    let id: UUID
    var name: String
    var code: String
    var color: String // Hex color without #
    var totalTasks: Int
    var completedTasks: Int
    
    init(id: UUID = UUID(),
         name: String,
         code: String,
         color: String,
         totalTasks: Int = 0,
         completedTasks: Int = 0) {
        self.id = id
        self.name = name
        self.code = code
        self.color = color
        self.totalTasks = totalTasks
        self.completedTasks = completedTasks
    }
    
    // Computed property for progress percentage
    var progressPercentage: Double {
        guard totalTasks > 0 else { return 0 }
        return Double(completedTasks) / Double(totalTasks) * 100
    }
}
