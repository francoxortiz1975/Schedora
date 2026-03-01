//
//  TaskDetailView.swift
//  Schedora
//
//  Detailed view of a task
//

import SwiftUI

// MARK: - Task Detail View Wrapper
struct TaskDetailViewWrapper: View {
    let task: Task
    let onTaskCompletionChanged: (Bool) -> Void
    var onTaskUpdated: ((Task) -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    @State private var localTask: Task
    
    init(task: Task, onTaskCompletionChanged: @escaping (Bool) -> Void, onTaskUpdated: ((Task) -> Void)? = nil, onDelete: (() -> Void)? = nil) {
        self.task = task
        self.onTaskCompletionChanged = onTaskCompletionChanged
        self.onTaskUpdated = onTaskUpdated
        self.onDelete = onDelete
        self._localTask = State(initialValue: task)
    }
    
    var body: some View {
        TaskDetailView(task: $localTask, onDelete: onDelete)
            .onChange(of: localTask.isCompleted) { newValue in
                onTaskCompletionChanged(newValue)
            }
            .onChange(of: localTask) { updatedTask in
                onTaskUpdated?(updatedTask)
            }
    }
}

// MARK: - Task Detail View
struct TaskDetailView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var task: Task
    var onDelete: (() -> Void)? = nil
    @State private var showingDeleteAlert = false
    
    var body: some View {
        NavigationView {
            ZStack {
                NotebookPaperBackground(showMargin: false)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Task Header Card (editable)
                        EditableTaskHeaderCard(task: $task)
                        
                        // Timeline indicator
                        TimelineIndicator(task: task)
                            .padding(.horizontal, 20)
                        
                        Spacer(minLength: 40)
                    }
                    .padding(.vertical, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        dismiss()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Back")
                                .font(.appBody)
                        }
                        .foregroundColor(.accentYellow)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingDeleteAlert = true
                    }) {
                        Image(systemName: "trash")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.criticalRed)
                    }
                }
            }
            .alert("Delete Task", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    onDelete?()
                    dismiss()
                }
            } message: {
                Text("Are you sure you want to delete '\(task.title)'?")
            }
        }
    }
}

// MARK: - Editable Task Header Card
struct EditableTaskHeaderCard: View {
    @Binding var task: Task
    @State private var showingTypePicker = false
    @State private var showingDurationPicker = false
    @State private var showingDatePicker = false
    @State private var showingPriorityPicker = false
    @State private var tempDuration: Int = 0
    @State private var tempDueDate: Date = Date()
    @State private var tempTaskType: TaskType = .assignment
    @State private var tempPriority: Priority = .chill
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Subject code with color bar
            HStack(spacing: 8) {
                Rectangle()
                    .fill(Color(hex: task.subjectColor))
                    .frame(width: 4, height: 24)
                
                Text(task.subjectCode)
                    .font(.appHeadline)
                    .foregroundColor(Color(hex: task.subjectColor))
                
                Spacer()
                
                // Priority badge (tappable)
                Button(action: {
                    tempPriority = task.priority
                    showingPriorityPicker = true
                }) {
                    Circle()
                        .fill(priorityColor)
                        .frame(width: 16, height: 16)
                        .overlay(
                            Circle()
                                .stroke(Color.textSecondary.opacity(0.3), lineWidth: 1)
                        )
                }
            }
            
            // Task title with completion circle
            HStack(spacing: 12) {
                // Completion circle
                Button(action: {
                    task.isCompleted.toggle()
                }) {
                    ZStack {
                        Circle()
                            .stroke(Color(hex: task.subjectColor), lineWidth: 2)
                            .frame(width: 28, height: 28)
                        
                        if task.isCompleted {
                            Circle()
                                .fill(Color(hex: task.subjectColor))
                                .frame(width: 18, height: 18)
                            
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                }
                
                // Task title
                Text(task.title)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(task.isCompleted ? .textSecondary : .textPrimary)
                    .strikethrough(task.isCompleted, color: .textSecondary)
            }
            
            // Subject name
            Text(task.subjectName)
                .font(.appBody)
                .foregroundColor(.textSecondary)
            
            Divider()
                .background(Color.textSecondary.opacity(0.3))
            
            // Task info grid (tappable to edit)
            HStack(spacing: 20) {
                // Task type (tappable)
                Button(action: {
                    tempTaskType = task.taskType
                    showingTypePicker = true
                }) {
                    EditableInfoBadge(
                        icon: "doc.text",
                        label: "TYPE",
                        value: task.taskTypeDisplayLabel
                    )
                }
                
                Divider()
                    .frame(height: 40)
                
                // Duration (tappable)
                Button(action: {
                    tempDuration = task.durationDays
                    showingDurationPicker = true
                }) {
                    EditableInfoBadge(
                        icon: "clock",
                        label: "DURATION",
                        value: "\(task.durationDays) days"
                    )
                }
                
                Divider()
                    .frame(height: 40)
                
                // Due date (tappable)
                Button(action: {
                    tempDueDate = task.dueDate
                    showingDatePicker = true
                }) {
                    EditableInfoBadge(
                        icon: "calendar",
                        label: "DUE DATE",
                        value: dueDateText,
                        valueColor: dueDateColor
                    )
                }
            }
        }
        .padding(20)
        .background(Color.bgSecondary)
        .cornerRadius(.cornerRadiusMedium)
        .overlay(
            RoundedRectangle(cornerRadius: .cornerRadiusMedium)
                .stroke(Color(hex: task.subjectColor).opacity(0.5), lineWidth: 2)
        )
        .padding(.horizontal, 20)
        .sheet(isPresented: $showingTypePicker) {
            TaskTypePickerSheet(selectedType: $tempTaskType) {
                task.taskType = tempTaskType
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showingDurationPicker) {
            DurationPickerSheet(duration: $tempDuration) {
                // Update start date based on new duration (-(n-1) because durationDays counts inclusive)
                let calendar = Calendar.current
                task.startDate = calendar.date(byAdding: .day, value: -(tempDuration - 1), to: task.dueDate) ?? task.startDate
            }
            .presentationDetents([.height(300)])
        }
        .sheet(isPresented: $showingDatePicker) {
            DatePickerSheet(date: $tempDueDate) {
                task.dueDate = tempDueDate
                // Recalculate start date to maintain duration (-(n-1) because durationDays is inclusive)
                let calendar = Calendar.current
                let currentDuration = task.durationDays
                task.startDate = calendar.date(byAdding: .day, value: -(currentDuration - 1), to: tempDueDate) ?? task.startDate
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showingPriorityPicker) {
            PriorityPickerSheet(selectedPriority: $tempPriority) {
                task.priority = tempPriority
            }
            .presentationDetents([.height(280)])
        }
    }
    
    private var priorityColor: Color {
        switch task.priority {
        case .critical: return .criticalRed
        case .important: return .importantYellow
        case .chill: return .chillGreen
        }
    }
    
    private var dueDateText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: task.dueDate)
    }
    
    private var dueDateColor: Color {
        let days = task.daysRemaining
        if days < 0 {
            return .criticalRed
        } else if days <= 3 {
            return .importantYellow
        } else {
            return .textSecondary
        }
    }
}

// MARK: - Editable Info Badge
struct EditableInfoBadge: View {
    let icon: String
    let label: String
    let value: String
    var valueColor: Color = .textPrimary
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(.accentYellow)
            
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.textSecondary)
                .textCase(.uppercase)
            
            HStack(spacing: 4) {
                Text(value)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(valueColor)
                
                Image(systemName: "pencil")
                    .font(.system(size: 8))
                    .foregroundColor(.textSecondary.opacity(0.6))
            }
        }
    }
}

// MARK: - Task Type Picker Sheet
struct TaskTypePickerSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedType: TaskType
    let onSave: () -> Void
    
    var body: some View {
        NavigationView {
            ZStack {
                NotebookPaperBackground(showMargin: false)
                
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 12) {
                        ForEach(TaskType.allCases, id: \.self) { taskType in
                            Button(action: {
                                selectedType = taskType
                            }) {
                                VStack(spacing: 6) {
                                    Text(taskType.rawValue)
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(selectedType == taskType ? .textPrimary : .textSecondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(selectedType == taskType ? Color.accentYellow.opacity(0.2) : Color.bgSecondary)
                                .cornerRadius(.cornerRadiusMedium)
                                .overlay(
                                    RoundedRectangle(cornerRadius: .cornerRadiusMedium)
                                        .stroke(selectedType == taskType ? Color.accentYellow : Color.clear, lineWidth: 2)
                                )
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Task Type")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave()
                        dismiss()
                    }
                    .foregroundColor(.accentOrange)
                    .fontWeight(.bold)
                }
            }
        }
    }
}

// MARK: - Duration Picker Sheet
struct DurationPickerSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var duration: Int
    let onSave: () -> Void
    
    var body: some View {
        NavigationView {
            ZStack {
                NotebookPaperBackground(showMargin: false)
                
                VStack(spacing: 24) {
                    Text("Select Duration")
                        .font(.appHeadline)
                        .foregroundColor(.textPrimary)
                    
                    // Quick options
                    HStack(spacing: 12) {
                        ForEach([3, 5, 7, 10, 14], id: \.self) { days in
                            Button(action: {
                                duration = days
                            }) {
                                Text("\(days)d")
                                    .font(.system(size: 14, weight: duration == days ? .bold : .medium))
                                    .foregroundColor(duration == days ? .textPrimary : .textSecondary)
                                    .frame(width: 50, height: 50)
                                    .background(duration == days ? Color.accentYellow.opacity(0.2) : Color.bgSecondary)
                                    .cornerRadius(.cornerRadiusSmall)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: .cornerRadiusSmall)
                                            .stroke(duration == days ? Color.accentYellow : Color.clear, lineWidth: 2)
                                    )
                            }
                        }
                    }
                    
                    // Custom stepper
                    HStack(spacing: 20) {
                        Button(action: {
                            if duration > 1 { duration -= 1 }
                        }) {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.accentOrange)
                        }
                        
                        Text("\(duration)")
                            .font(.system(size: 48, weight: .bold))
                            .foregroundColor(.textPrimary)
                            .frame(width: 80)
                        
                        Button(action: {
                            duration += 1
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.accentOrange)
                        }
                    }
                    
                    Text("days")
                        .font(.appBody)
                        .foregroundColor(.textSecondary)
                }
                .padding()
            }
            .navigationTitle("Duration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave()
                        dismiss()
                    }
                    .foregroundColor(.accentOrange)
                    .fontWeight(.bold)
                }
            }
        }
    }
}

// MARK: - Date Picker Sheet
struct DatePickerSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var date: Date
    let onSave: () -> Void
    
    var body: some View {
        NavigationView {
            ZStack {
                NotebookPaperBackground(showMargin: false)
                
                VStack {
                    DatePicker(
                        "Due Date",
                        selection: $date,
                        in: Date()...,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .colorScheme(.light)
                    .padding()
                }
            }
            .navigationTitle("Due Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave()
                        dismiss()
                    }
                    .foregroundColor(.accentOrange)
                    .fontWeight(.bold)
                }
            }
        }
    }
}

// MARK: - Priority Picker Sheet
struct PriorityPickerSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedPriority: Priority
    let onSave: () -> Void
    
    var body: some View {
        NavigationView {
            ZStack {
                NotebookPaperBackground(showMargin: false)
                
                VStack(spacing: 16) {
                    Text("Select Priority")
                        .font(.appHeadline)
                        .foregroundColor(.textPrimary)
                        .padding(.top, 20)
                    
                    VStack(spacing: 12) {
                        PriorityPickerOption(
                            priority: .critical,
                            label: "Critical",
                            description: "Urgent - needs immediate attention",
                            color: .criticalRed,
                            isSelected: selectedPriority == .critical
                        ) {
                            selectedPriority = .critical
                        }
                        
                        PriorityPickerOption(
                            priority: .important,
                            label: "Important",
                            description: "Should be done soon",
                            color: .importantYellow,
                            isSelected: selectedPriority == .important
                        ) {
                            selectedPriority = .important
                        }
                        
                        PriorityPickerOption(
                            priority: .chill,
                            label: "Chill",
                            description: "Can wait, no rush",
                            color: .chillGreen,
                            isSelected: selectedPriority == .chill
                        ) {
                            selectedPriority = .chill
                        }
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                }
            }
            .navigationTitle("Priority")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave()
                        dismiss()
                    }
                    .foregroundColor(.accentOrange)
                    .fontWeight(.bold)
                }
            }
        }
    }
}

// MARK: - Priority Picker Option Row
struct PriorityPickerOption: View {
    let priority: Priority
    let label: String
    let description: String
    let color: Color
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                Circle()
                    .fill(color)
                    .frame(width: 24, height: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.textPrimary)
                    
                    Text(description)
                        .font(.system(size: 12))
                        .foregroundColor(.textSecondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.accentOrange)
                }
            }
            .padding(16)
            .background(isSelected ? Color.accentOrange.opacity(0.1) : Color.bgSecondary)
            .cornerRadius(.cornerRadiusMedium)
            .overlay(
                RoundedRectangle(cornerRadius: .cornerRadiusMedium)
                    .stroke(isSelected ? color : Color.clear, lineWidth: 2)
            )
        }
    }
}

// MARK: - Task Header Card (legacy, kept for compatibility)
struct TaskHeaderCard: View {
    let task: Task
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Subject code with color bar
            HStack(spacing: 8) {
                Rectangle()
                    .fill(Color(hex: task.subjectColor))
                    .frame(width: 4, height: 24)
                
                Text(task.subjectCode)
                    .font(.appHeadline)
                    .foregroundColor(Color(hex: task.subjectColor))
                
                Spacer()
                
                // Priority badge
                Circle()
                    .fill(priorityColor)
                    .frame(width: 12, height: 12)
            }
            
            // Task title
            Text(task.title)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.textPrimary)
            
            // Subject name
            Text(task.subjectName)
                .font(.appBody)
                .foregroundColor(.textSecondary)
            
            Divider()
                .background(Color.textSecondary.opacity(0.3))
            
            // Task info grid
            HStack(spacing: 20) {
                // Task type
                InfoBadge(
                    icon: "doc.text",
                    label: "TYPE",
                    value: task.taskTypeDisplayLabel
                )
                
                Divider()
                    .frame(height: 40)
                
                // Duration
                InfoBadge(
                    icon: "clock",
                    label: "DURATION",
                    value: "\(task.durationDays) days"
                )
                
                Divider()
                    .frame(height: 40)
                
                // Due date
                InfoBadge(
                    icon: "calendar",
                    label: "DUE DATE",
                    value: dueDateText,
                    valueColor: dueDateColor
                )
            }
        }
        .padding(20)
        .background(Color.bgSecondary)
        .cornerRadius(.cornerRadiusMedium)
        .overlay(
            RoundedRectangle(cornerRadius: .cornerRadiusMedium)
                .stroke(Color(hex: task.subjectColor).opacity(0.5), lineWidth: 2)
        )
        .padding(.horizontal, 20)
    }
    
    private var priorityColor: Color {
        switch task.priority {
        case .critical: return .criticalRed
        case .important: return .importantYellow
        case .chill: return .chillGreen
        }
    }
    
    private var dueDateText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: task.dueDate)
    }
    
    private var dueDateColor: Color {
        let days = task.daysRemaining
        if days < 0 {
            return .criticalRed
        } else if days <= 3 {
            return .importantYellow
        } else {
            return .textSecondary
        }
    }
}

// MARK: - Info Badge
struct InfoBadge: View {
    let icon: String
    let label: String
    let value: String
    var valueColor: Color = .textPrimary
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(.accentYellow)
            
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.textSecondary)
                .textCase(.uppercase)
            
            Text(value)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(valueColor)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Mini Task Card Wrapper (with Manager)
struct MiniTaskCardWrapper: View {
    let miniTask: MiniTask
    let task: Task
    @ObservedObject var miniTaskManager: MiniTaskManager
    let onTaskCompletionChanged: (Bool) -> Void
    
    var body: some View {
        let binding = Binding<MiniTask>(
            get: {
                miniTaskManager.getMiniTasks(for: task.id)
                    .first(where: { $0.id == miniTask.id }) ?? miniTask
            },
            set: { _ in }
        )
        
        MiniTaskCard(
            miniTask: binding,
            taskColor: task.subjectColor,
            onToggle: { isCompleted in
                miniTaskManager.toggleMiniTask(taskId: task.id, miniTaskId: miniTask.id)
                
                // Check if all tasks are completed
                let isFullyCompleted = miniTaskManager.isTaskFullyCompleted(taskId: task.id)
                onTaskCompletionChanged(isFullyCompleted)
            }
        )
    }
}

// MARK: - Mini Task Card
struct MiniTaskCard: View {
    @Binding var miniTask: MiniTask
    let taskColor: String
    let onToggle: (Bool) -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Day number badge
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(hex: taskColor).opacity(0.2))
                    .frame(width: 44, height: 44)
                
                Text("Día\n\(miniTask.dayNumber)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color(hex: taskColor))
                    .multilineTextAlignment(.center)
            }
            
            // Mini task content
            VStack(alignment: .leading, spacing: 6) {
                Text(miniTask.title)
                    .font(.appBody)
                    .foregroundColor(.textPrimary)
                    .strikethrough(miniTask.isCompleted, color: .textSecondary)
                
                Text(miniTask.description)
                    .font(.appCaption)
                    .foregroundColor(.textSecondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            // Checkbox
            Button(action: {
                miniTask.isCompleted.toggle()
                onToggle(miniTask.isCompleted)
            }) {
                ZStack {
                    Circle()
                        .stroke(Color(hex: taskColor), lineWidth: 2)
                        .frame(width: 28, height: 28)
                    
                    if miniTask.isCompleted {
                        Circle()
                            .fill(Color(hex: taskColor))
                            .frame(width: 20, height: 20)
                        
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .padding(14)
        .background(miniTask.isCompleted ? Color.bgSecondary.opacity(0.5) : Color.bgSecondary)
        .cornerRadius(.cornerRadiusMedium)
        .overlay(
            RoundedRectangle(cornerRadius: .cornerRadiusMedium)
                .stroke(
                    miniTask.isCompleted ?
                        Color(hex: taskColor).opacity(0.3) :
                        Color(hex: taskColor).opacity(0.5),
                    lineWidth: 1
                )
        )
        .opacity(miniTask.isCompleted ? 0.7 : 1.0)
    }
}

// MARK: - Timeline Indicator
struct TimelineIndicator: View {
    let task: Task
    private let calendar = Calendar.current
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Timeline")
                .font(.appHeadline)
                .foregroundColor(.textPrimary)
            
            HStack(spacing: 0) {
                // Start date
                VStack(alignment: .leading, spacing: 4) {
                    Text("START")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.textSecondary)
                    
                    Text(formatDate(task.startDate))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.chillGreen)
                }
                
                // Arrow line
                VStack {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    .chillGreen,
                                    Color(hex: task.subjectColor),
                                    dueDateColor
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 3)
                        .padding(.horizontal, 8)
                }
                .padding(.top, 20)
                
                // Due date
                VStack(alignment: .trailing, spacing: 4) {
                    Text("ENTREGA")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.textSecondary)
                    
                    Text(formatDate(task.dueDate))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(dueDateColor)
                }
            }
        }
        .padding(16)
        .background(Color.bgSecondary)
        .cornerRadius(.cornerRadiusMedium)
    }
    
    private var dueDateColor: Color {
        let days = task.daysRemaining
        if days < 0 {
            return .criticalRed
        } else if days <= 3 {
            return .importantYellow
        } else {
            return Color(hex: task.subjectColor)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }
}

// MARK: - Mini Task Model
struct MiniTask: Identifiable {
    let id: UUID
    let dayNumber: Int
    let title: String
    let description: String
    var isCompleted: Bool
    
    init(id: UUID = UUID(), dayNumber: Int, title: String, description: String, isCompleted: Bool = false) {
        self.id = id
        self.dayNumber = dayNumber
        self.title = title
        self.description = description
        self.isCompleted = isCompleted
    }
}

// MARK: - AI Mini Task Generator
func generateMiniTasks(for task: Task) -> [MiniTask] {
    let daysRemaining = max(task.durationDays, 1)
    var miniTasks: [MiniTask] = []
    
    // AI-generated mini tasks based on task type
    switch task.taskType {
    case .exam, .midterm, .final:
        miniTasks = generateExamMiniTasks(for: task, days: daysRemaining)
    case .assignment:
        miniTasks = generateAssignmentMiniTasks(for: task, days: daysRemaining)
    case .project:
        miniTasks = generateProjectMiniTasks(for: task, days: daysRemaining)
    case .quiz:
        miniTasks = generateQuizMiniTasks(for: task, days: daysRemaining)
    case .homework:
        miniTasks = generateHomeworkMiniTasks(for: task, days: daysRemaining)
    case .reading:
        miniTasks = generateReadingMiniTasks(for: task, days: daysRemaining)
    case .other:
        miniTasks = generateAssignmentMiniTasks(for: task, days: daysRemaining) // Use assignment pattern for custom types
    }
    
    return miniTasks
}

// MARK: - Task Type Specific Generators

func generateExamMiniTasks(for task: Task, days: Int) -> [MiniTask] {
    let tasks = [
        "Review complete syllabus",
        "Identify weak topics",
        "Create key concepts summary",
        "Practice exercises",
        "Review past exams",
        "Study with flashcards",
        "Solve difficult problems",
        "Review formulas and definitions",
        "Take practice exam",
        "Final review and rest"
    ]
    return distributeTasksOverDays(tasks: tasks, days: days, taskType: "Study")
}

func generateAssignmentMiniTasks(for task: Task, days: Int) -> [MiniTask] {
    let tasks = [
        "Read instructions",
        "Research necessary references",
        "Create work structure",
        "Complete initial draft",
        "Review and edit content"
    ]
    return distributeTasksOverDays(tasks: tasks, days: days, taskType: "Work")
}

func generateProjectMiniTasks(for task: Task, days: Int) -> [MiniTask] {
    let tasks = [
        "Define scope and objectives",
        "Research and analysis",
        "Design architecture/structure",
        "Implement basic functionality",
        "Develop main features",
        "Integrate components",
        "Conduct testing",
        "Document the project",
        "Optimize and refine",
        "Prepare presentation",
        "Final review and submit"
    ]
    return distributeTasksOverDays(tasks: tasks, days: days, taskType: "Develop")
}

func generateQuizMiniTasks(for task: Task, days: Int) -> [MiniTask] {
    let tasks = [
        "Review class notes",
        "Practice exercises",
        "Quick final review"
    ]
    return distributeTasksOverDays(tasks: tasks, days: days, taskType: "Prepare")
}

func generateHomeworkMiniTasks(for task: Task, days: Int) -> [MiniTask] {
    let tasks = [
        "Read the questions",
        "Solve exercises",
        "Review answers",
        "Prepare submission"
    ]
    return distributeTasksOverDays(tasks: tasks, days: days, taskType: "Complete")
}

func generateReadingMiniTasks(for task: Task, days: Int) -> [MiniTask] {
    let tasks = [
        "Read assigned chapters",
        "Take important notes"
    ]
    return distributeTasksOverDays(tasks: tasks, days: days, taskType: "Read")
}

// MARK: - Helper to distribute tasks over days
func distributeTasksOverDays(tasks: [String], days: Int, taskType: String) -> [MiniTask] {
    var miniTasks: [MiniTask] = []
    let tasksToUse = Array(tasks.prefix(days))
    
    for (index, taskTitle) in tasksToUse.enumerated() {
        miniTasks.append(
            MiniTask(
                dayNumber: index + 1,
                title: taskTitle,
                description: "\(taskType) day \(index + 1) of \(days)"
            )
        )
    }
    
    // If we need more tasks than available, repeat the last task
    if days > tasksToUse.count {
        for day in (tasksToUse.count + 1)...days {
            miniTasks.append(
                MiniTask(
                    dayNumber: day,
                    title: "Continue \(taskType.lowercased())",
                    description: "\(taskType) day \(day) of \(days)"
                )
            )
        }
    }
    
    return miniTasks
}

// MARK: - Preview
#Preview {
    TaskDetailViewWrapper(
        task: Task(
            title: "Midterm Exam",
            taskType: .exam,
            priority: .critical,
            dueDate: Date().addingTimeInterval(10 * 24 * 60 * 60),
            subjectName: "Data Structures",
            subjectCode: "CSC373",
            subjectColor: "4ECDC4"
        ),
        onTaskCompletionChanged: { isCompleted in
            print("Task completion changed: \(isCompleted)")
        }
    )
}
