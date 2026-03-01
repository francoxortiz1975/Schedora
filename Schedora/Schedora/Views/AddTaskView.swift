//
//  AddTaskView.swift
//  Schedora
//
//  Manual task creation with intuitive UI
//

import SwiftUI

struct AddTaskView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var taskManager: TaskManager
    let subjects: [Subject]
    
    @State private var taskTitle: String = ""
    @State private var selectedSubject: Subject?
    @State private var selectedTaskType: TaskType = .assignment
    @State private var customTaskLabel: String = ""
    @State private var selectedPriority: Priority = .important
    @State private var dueDate: Date = Date().addingTimeInterval(7 * 24 * 60 * 60) // Default 7 days ahead
    @State private var startDate: Date = Date()
    @State private var customDuration: Int = 5 // Default duration
    
    var body: some View {
        NavigationView {
            ZStack {
                NotebookPaperBackground(showMargin: false)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Title input
                        VStack(alignment: .leading, spacing: 8) {
                            Text("TASK TITLE")
                                .font(.appCaptionBold)
                                .foregroundColor(.textSecondary)
                            
                            ZStack(alignment: .leading) {
                                if taskTitle.isEmpty {
                                    Text("e.g. Midterm Exam")
                                        .font(.appBody)
                                        .foregroundColor(.textSecondary)
                                        .padding(.horizontal, 16)
                                }
                                
                                TextField("", text: $taskTitle)
                                    .font(.appBody)
                                    .foregroundColor(.textPrimary)
                                    .padding(16)
                            }
                            .background(Color.bgSecondary)
                            .cornerRadius(.cornerRadiusMedium)
                            .overlay(
                                RoundedRectangle(cornerRadius: .cornerRadiusMedium)
                                    .stroke(Color.textSecondary.opacity(0.2), lineWidth: 1)
                            )
                        }
                        
                        // Subject selection (Color Grid)
                        VStack(alignment: .leading, spacing: 12) {
                            Text("SUBJECT")
                                .font(.appCaptionBold)
                                .foregroundColor(.textSecondary)
                            
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 12) {
                                ForEach(subjects) { subject in
                                    SubjectOption(
                                        subject: subject,
                                        isSelected: selectedSubject?.id == subject.id,
                                        onTap: {
                                            selectedSubject = subject
                                        }
                                    )
                                }
                            }
                        }
                        
                        // Task type selector
                        VStack(alignment: .leading, spacing: 12) {
                            Text("TASK TYPE")
                                .font(.appCaptionBold)
                                .foregroundColor(.textSecondary)
                            
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 12) {
                                ForEach(TaskType.allCases.filter { $0 != .other }, id: \.self) { taskType in
                                    TaskTypeOption(
                                        taskType: taskType,
                                        isSelected: selectedTaskType == taskType,
                                        onTap: {
                                            selectedTaskType = taskType
                                            customDuration = taskType.preparationDays
                                            updateStartDate()
                                        }
                                    )
                                }
                                
                                // Custom "Other" option
                                OtherTaskTypeOption(
                                    customLabel: $customTaskLabel,
                                    isSelected: selectedTaskType == .other,
                                    onTap: {
                                        selectedTaskType = .other
                                        customDuration = TaskType.other.preparationDays
                                        updateStartDate()
                                    }
                                )
                            }
                        }
                        
                        // Duration picker
                        VStack(alignment: .leading, spacing: 12) {
                            Text("DURATION (DAYS)")
                                .font(.appCaptionBold)
                                .foregroundColor(.textSecondary)
                            
                            HStack(spacing: 16) {
                                // Quick duration options
                                ForEach([3, 5, 7, 10, 14], id: \.self) { days in
                                    DurationOption(
                                        days: days,
                                        isSelected: customDuration == days,
                                        onTap: {
                                            customDuration = days
                                            updateStartDate()
                                        }
                                    )
                                }
                                
                                // Custom input
                                HStack(spacing: 4) {
                                    TextField("", value: $customDuration, format: .number)
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.textPrimary)
                                        .multilineTextAlignment(.center)
                                        .frame(width: 40)
                                        .keyboardType(.numberPad)
                                        .onChange(of: customDuration) { _, _ in
                                            updateStartDate()
                                        }
                                    
                                    Text("d")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.textSecondary)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(Color.accentOrange.opacity(0.1))
                                .cornerRadius(.cornerRadiusMedium)
                                .overlay(
                                    RoundedRectangle(cornerRadius: .cornerRadiusMedium)
                                        .stroke(Color.accentOrange, lineWidth: 1)
                                )
                            }
                        }
                        
                        // Priority selector
                        VStack(alignment: .leading, spacing: 12) {
                            Text("PRIORITY")
                                .font(.appCaptionBold)
                                .foregroundColor(.textSecondary)
                            
                            HStack(spacing: 12) {
                                ForEach(Priority.allCases, id: \.self) { priority in
                                    PriorityOption(
                                        priority: priority,
                                        isSelected: selectedPriority == priority,
                                        onTap: {
                                            selectedPriority = priority
                                        }
                                    )
                                }
                            }
                        }
                        
                        // Due date picker
                        VStack(alignment: .leading, spacing: 8) {
                            Text("DUE DATE")
                                .font(.appCaptionBold)
                                .foregroundColor(.textSecondary)
                            
                            DatePicker(
                                "",
                                selection: $dueDate,
                                in: Date()...,
                                displayedComponents: .date
                            )
                            .datePickerStyle(.graphical)
                            .colorScheme(.light)
                            .onChange(of: dueDate) { _, _ in
                                updateStartDate()
                            }
                        }
                        
                        // Duration info
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("START")
                                        .font(.appCaption)
                                        .foregroundColor(.textSecondary)
                                    Text(formatDate(startDate))
                                        .font(.appBodyBold)
                                        .foregroundColor(.chillGreen)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "arrow.right")
                                    .foregroundColor(.textSecondary)
                                
                                Spacer()
                                
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text("DUE")
                                        .font(.appCaption)
                                        .foregroundColor(.textSecondary)
                                    Text(formatDate(dueDate))
                                        .font(.appBodyBold)
                                        .foregroundColor(.criticalRed)
                                }
                            }
                            .padding(16)
                            .background(Color.bgSecondary)
                            .cornerRadius(.cornerRadiusMedium)
                            
                            Text("\(customDuration) days duration")
                                .font(.appCaption)
                                .foregroundColor(.textSecondary)
                                .padding(.leading, 4)
                        }
                        
                        Spacer(minLength: 40)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.textSecondary)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveTask()
                    }
                    .foregroundColor(.accentOrange)
                    .disabled(!isValid)
                }
            }
        }
        .onAppear {
            customDuration = selectedTaskType.preparationDays
        }
    }
    
    private var isValid: Bool {
        !taskTitle.isEmpty && selectedSubject != nil
    }
    
    private func updateStartDate() {
        let calendar = Calendar.current
        // Use -(duration - 1) so that "3 days" = day0..day2 (3 columns), not day-3..day2 (4 columns)
        startDate = calendar.date(byAdding: .day, value: -(customDuration - 1), to: dueDate) ?? dueDate
    }
    
    private func saveTask() {
        guard let subject = selectedSubject else { return }
        
        let newTask = Task(
            title: taskTitle,
            taskType: selectedTaskType,
            customTaskLabel: selectedTaskType == .other ? customTaskLabel : nil,
            priority: selectedPriority,
            dueDate: dueDate,
            startDate: startDate,
            customDuration: customDuration,
            subjectName: subject.name,
            subjectCode: subject.code,
            subjectColor: subject.color,
            isCompleted: false
        )
        
        taskManager.addTask(newTask)
        dismiss()
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }
}

// MARK: - Subject Option (Color Grid Item)
struct SubjectOption: View {
    let subject: Subject
    let isSelected: Bool
    var onTap: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 8) {
            Circle()
                .fill(Color(hex: subject.color))
                .frame(width: 50, height: 50)
                .overlay(
                    Circle()
                        .stroke(Color.accentYellow, lineWidth: isSelected ? 3 : 0)
                )
            
            Text(subject.code)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(isSelected ? .textPrimary : .textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(isSelected ? Color(hex: subject.color).opacity(0.1) : Color.bgSecondary)
        .cornerRadius(.cornerRadiusMedium)
        .onTapGesture {
            onTap?()
        }
    }
}

// MARK: - Task Type Option
struct TaskTypeOption: View {
    let taskType: TaskType
    let isSelected: Bool
    var onTap: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 6) {
            Text(taskType.rawValue)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(isSelected ? .textPrimary : .textSecondary)
            
            Text("\(taskType.preparationDays)d")
                .font(.system(size: 10))
                .foregroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(isSelected ? Color.accentYellow.opacity(0.2) : Color.bgSecondary)
        .cornerRadius(.cornerRadiusMedium)
        .overlay(
            RoundedRectangle(cornerRadius: .cornerRadiusMedium)
                .stroke(isSelected ? Color.accentYellow : Color.clear, lineWidth: 2)
        )
        .onTapGesture {
            onTap?()
        }
    }
}

// MARK: - Other Task Type Option (Custom)
struct OtherTaskTypeOption: View {
    @Binding var customLabel: String
    let isSelected: Bool
    var onTap: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 6) {
            if isSelected {
                TextField("Custom", text: $customLabel)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.textPrimary)
                    .multilineTextAlignment(.center)
                    .frame(height: 16)
            } else {
                Text("OTHER")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.textSecondary)
            }
            
            Image(systemName: "pencil")
                .font(.system(size: 10))
                .foregroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(isSelected ? Color.accentOrange.opacity(0.2) : Color.bgSecondary)
        .cornerRadius(.cornerRadiusMedium)
        .overlay(
            RoundedRectangle(cornerRadius: .cornerRadiusMedium)
                .stroke(isSelected ? Color.accentOrange : Color.clear, lineWidth: 2)
        )
        .onTapGesture {
            onTap?()
        }
    }
}

// MARK: - Duration Option
struct DurationOption: View {
    let days: Int
    let isSelected: Bool
    var onTap: (() -> Void)?
    
    var body: some View {
        Text("\(days)d")
            .font(.system(size: 12, weight: isSelected ? .bold : .medium))
            .foregroundColor(isSelected ? .textPrimary : .textSecondary)
            .frame(width: 40, height: 36)
            .background(isSelected ? Color.accentYellow.opacity(0.2) : Color.bgSecondary)
            .cornerRadius(.cornerRadiusSmall)
            .overlay(
                RoundedRectangle(cornerRadius: .cornerRadiusSmall)
                    .stroke(isSelected ? Color.accentYellow : Color.clear, lineWidth: 2)
            )
            .onTapGesture {
                onTap?()
            }
    }
}

// MARK: - Priority Option
struct PriorityOption: View {
    let priority: Priority
    let isSelected: Bool
    var onTap: (() -> Void)?
    
    private var priorityColor: Color {
        switch priority {
        case .critical: return .criticalRed
        case .important: return .importantYellow
        case .chill: return .chillGreen
        }
    }
    
    private var priorityEmoji: String {
        switch priority {
        case .critical: return "🔴"
        case .important: return "🟡"
        case .chill: return "🟢"
        }
    }
    
    var body: some View {
        VStack(spacing: 8) {
            Text(priorityEmoji)
                .font(.system(size: 32))
            
            Text(priority.rawValue)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(isSelected ? .textPrimary : .textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(isSelected ? priorityColor.opacity(0.2) : Color.bgSecondary)
        .cornerRadius(.cornerRadiusMedium)
        .overlay(
            RoundedRectangle(cornerRadius: .cornerRadiusMedium)
                .stroke(isSelected ? priorityColor : Color.clear, lineWidth: 2)
        )
        .onTapGesture {
            onTap?()
        }
    }
}

#Preview {
    AddTaskView(
        taskManager: TaskManager(),
        subjects: [
            Subject(name: "Programming Languages", code: "CSC324", color: "FF6B6B"),
            Subject(name: "Data Structures", code: "CSC373", color: "4ECDC4"),
            Subject(name: "Linear Algebra", code: "MATH223", color: "FFE66D")
        ]
    )
}
