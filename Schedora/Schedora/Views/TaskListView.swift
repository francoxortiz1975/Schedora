//
//  TaskListView.swift
//  Schedora
//
//  List view with time-based filters (TODAY, THIS WEEK, THIS MONTH, ALL)
//

import SwiftUI

enum TimeFilter: String, CaseIterable {
    case today = "TODAY"
    case thisWeek = "THIS WEEK"
    case thisMonth = "THIS MONTH"
    case all = "ALL"
}

struct TaskListView: View {
    @ObservedObject var taskManager: TaskManager
    @ObservedObject var subjectManager: SubjectManager
    @State private var selectedFilter: TimeFilter = .today
    @State private var selectedSubject: String = "ALL"
    @State private var prioritizedMissions: [PrioritizedMiniMission] = []
    @State private var isLoadingPriorities = false
    @StateObject private var miniTaskManager = MiniTaskManager.shared
    
    private let calendar = Calendar.current
    
    // Filter tasks by time and completion status
    private var filteredTasks: [Task] {
        let timeTasks = taskManager.tasks.filter { task in
            switch selectedFilter {
            case .today:
                return taskIsInToday(task)
            case .thisWeek:
                return taskIsInThisWeek(task)
            case .thisMonth:
                return taskIsInThisMonth(task)
            case .all:
                return true
            }
        }
        
        if selectedSubject == "ALL" {
            return timeTasks
        } else {
            return timeTasks.filter { $0.subjectCode == selectedSubject }
        }
    }
    
    // Group filtered tasks by subject
    private var tasksBySubject: [String: [Task]] {
        Dictionary(grouping: filteredTasks.sorted(by: { $0.dueDate < $1.dueDate }), by: { $0.subjectCode })
    }
    
    private var subjectOrder: [String] {
        Array(Set(filteredTasks.map { $0.subjectCode })).sorted()
    }
    
    // Count tasks by status
    private var completedCount: Int {
        filteredTasks.filter { $0.isCompleted }.count
    }
    
    private var totalCount: Int {
        filteredTasks.count
    }
    
    // Get today's mini-mission candidates (all available)
    private var todayMiniMissionCandidates: [(task: Task, miniTask: MiniTask)] {
        var missions: [(task: Task, miniTask: MiniTask)] = []
        
        // Get tasks for today
        let todayTasks = taskManager.tasks.filter { taskIsInToday($0) && !$0.isCompleted }
        
        // Generate mini tasks for each task and find today's mission
        for task in todayTasks {
            // Initialize mini tasks if needed
            miniTaskManager.initializeMiniTasks(for: task.id, task: task)
            let miniTasks = miniTaskManager.getMiniTasks(for: task.id)
            
            // Calculate which day we are in the task duration
            let daysSinceStart = calendar.dateComponents([.day], from: calendar.startOfDay(for: task.startDate), to: calendar.startOfDay(for: Date())).day ?? 0
            let currentDayNumber = daysSinceStart + 1
            
            // Find the mini task for today (if within range)
            if let todayMiniTask = miniTasks.first(where: { $0.dayNumber == currentDayNumber && !$0.isCompleted }) {
                missions.append((task: task, miniTask: todayMiniTask))
            }
        }
        
        return missions
    }
    
    var body: some View {
        ZStack {
            NotebookPaperBackground(showMargin: false)
            
            VStack(spacing: 0) {
                // Header with stats
                VStack(alignment: .leading, spacing: 16) {
                    // Title
                    Text("My Tasks")
                        .font(.appTitle)
                        .foregroundColor(.textPrimary)
                    
                    // Progress bar
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("\(completedCount) of \(totalCount) completed")
                                .font(.appBody)
                                .foregroundColor(.textSecondary)
                            
                            Spacer()
                            
                            Text("\(totalCount > 0 ? Int((Double(completedCount) / Double(totalCount)) * 100) : 0)%")
                                .font(.appHeadline)
                                .foregroundColor(.accentYellow)
                        }
                        
                        // Progress bar
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .fill(Color.bgSecondary)
                                    .frame(height: 8)
                                    .cornerRadius(4)
                                
                                Rectangle()
                                    .fill(Color.accentYellow)
                                    .frame(width: totalCount > 0 ? (CGFloat(completedCount) / CGFloat(totalCount)) * geometry.size.width : 0, height: 8)
                                    .cornerRadius(4)
                            }
                        }
                        .frame(height: 8)
                    }
                }
                .sectionCard()
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 16)
                
                // Time filter pills
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(TimeFilter.allCases, id: \.self) { filter in
                            TimeFilterPill(
                                title: filter.rawValue,
                                isSelected: selectedFilter == filter,
                                action: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        selectedFilter = filter
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 16)
                
                // Subject filter pills
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        // ALL button
                        SubjectFilterPill(
                            code: "ALL",
                            color: "FFFFFF",
                            isSelected: selectedSubject == "ALL",
                            action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedSubject = "ALL"
                                }
                            }
                        )
                        
                        // Subject buttons
                        ForEach(subjectManager.subjects.filter { $0.code != "ALL" }, id: \.id) { subject in
                            SubjectFilterPill(
                                code: subject.code,
                                color: subject.color,
                                isSelected: selectedSubject == subject.code,
                                action: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        selectedSubject = subject.code
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 16)
                
                // Task list by subject
                ScrollView {
                    VStack(spacing: 24) {
                        // TO DO TODAY Card (only show if selectedFilter is .today)
                        if selectedFilter == .today {
                            if isLoadingPriorities {
                                // Loading state
                                ToDoTodayLoadingCard()
                                    .padding(.horizontal, 20)
                            } else if !prioritizedMissions.isEmpty {
                                // Show AI prioritized missions
                                ToDoTodayCard(
                                    prioritizedMissions: prioritizedMissions,
                                    taskManager: taskManager,
                                    miniTaskManager: miniTaskManager
                                )
                                .padding(.horizontal, 20)
                            }
                        }
                        
                        if filteredTasks.isEmpty {
                            // Empty state
                            VStack(spacing: 16) {
                                Image(systemName: "checkmark.circle")
                                    .font(.system(size: 60))
                                    .foregroundColor(.chillGreen)
                                
                                Text("No tasks!")
                                    .font(.appHeadline)
                                    .foregroundColor(.textPrimary)
                                
                                Text("Enjoy your free time")
                                    .font(.appBody)
                                    .foregroundColor(.textSecondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 80)
                        } else {
                            ForEach(subjectOrder, id: \.self) { subjectCode in
                                if let subjectTasks = tasksBySubject[subjectCode],
                                   let firstTask = subjectTasks.first {
                                    SubjectTaskSection(
                                        subjectCode: subjectCode,
                                        subjectColor: firstTask.subjectColor,
                                        subjectName: firstTask.subjectName,
                                        tasks: subjectTasks,
                                        onTaskToggle: { task, isCompleted in
                                            taskManager.toggleTaskCompletion(task, isCompleted: isCompleted)
                                        },
                                        onTaskDelete: { task in
                                            taskManager.removeTask(task)
                                        },
                                        onTaskUpdate: { updatedTask in
                                            taskManager.updateTask(updatedTask)
                                        }
                                    )
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                }
            }
        }
        .onAppear {
            loadPrioritizedMissions()
        }
        .onChange(of: selectedFilter) { _ in
            if selectedFilter == .today {
                loadPrioritizedMissions()
            }
        }
        .onChange(of: taskManager.tasks.count) { _ in
            if selectedFilter == .today {
                loadPrioritizedMissions()
            }
        }
    }
    
    // MARK: - Load Prioritized Missions with Claude AI
    private func loadPrioritizedMissions() {
        let candidates = todayMiniMissionCandidates
        
        guard !candidates.isEmpty else {
            prioritizedMissions = []
            return
        }
        
        isLoadingPriorities = true
        
        GeminiService.shared.prioritizeMiniMissions(candidates: candidates) { prioritized in
            self.prioritizedMissions = prioritized
            self.isLoadingPriorities = false
        }
    }
    
    // MARK: - Time Filter Helpers
    
    private func taskIsInToday(_ task: Task) -> Bool {
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        
        // Check if task interval overlaps with today
        return task.startDate < tomorrow && task.dueDate >= today
    }
    
    private func taskIsInThisWeek(_ task: Task) -> Bool {
        let today = Date()
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start,
              let weekEnd = calendar.dateInterval(of: .weekOfYear, for: today)?.end else {
            return false
        }
        
        // Check if task interval overlaps with this week
        return task.startDate < weekEnd && task.dueDate >= weekStart
    }
    
    private func taskIsInThisMonth(_ task: Task) -> Bool {
        let today = Date()
        guard let monthStart = calendar.dateInterval(of: .month, for: today)?.start,
              let monthEnd = calendar.dateInterval(of: .month, for: today)?.end else {
            return false
        }
        
        // Check if task interval overlaps with this month
        return task.startDate < monthEnd && task.dueDate >= monthStart
    }
}

// MARK: - Time Filter Pill
struct TimeFilterPill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(isSelected ? .bgPrimary : .textSecondary)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(isSelected ? Color.accentYellow : Color.bgSecondary)
                .cornerRadius(20)
        }
    }
}

// MARK: - Subject Filter Pill
struct SubjectFilterPill: View {
    let code: String
    let color: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color(hex: color))
                    .frame(width: 8, height: 8)
                
                Text(code)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(isSelected ? .textPrimary : .textSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                isSelected ?
                    Color(hex: color).opacity(0.2) :
                    Color.bgSecondary
            )
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color(hex: color) : Color.clear, lineWidth: 2)
            )
        }
    }
}

// MARK: - Subject Task Section
struct SubjectTaskSection: View {
    let subjectCode: String
    let subjectColor: String
    let subjectName: String
    let tasks: [Task]
    let onTaskToggle: (Task, Bool) -> Void
    var onTaskDelete: ((Task) -> Void)? = nil
    var onTaskUpdate: ((Task) -> Void)? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Subject header
            HStack(spacing: 8) {
                Rectangle()
                    .fill(Color(hex: subjectColor))
                    .frame(width: 4, height: 20)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(subjectCode)
                        .font(.appHeadline)
                        .foregroundColor(Color(hex: subjectColor))
                    
                    Text(subjectName)
                        .font(.appCaption)
                        .foregroundColor(.textSecondary)
                }
                
                Spacer()
                
                // Task count badge
                Text("\(tasks.count)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color(hex: subjectColor))
                    .frame(width: 28, height: 28)
                    .background(Color(hex: subjectColor).opacity(0.2))
                    .cornerRadius(14)
            }
            
            // Task cards
            VStack(spacing: 8) {
                ForEach(tasks) { task in
                    TaskListCard(task: task, onToggle: onTaskToggle, onDelete: onTaskDelete, onTaskUpdate: onTaskUpdate)
                }
            }
        }
    }
}

// MARK: - Task List Card
struct TaskListCard: View {
    let task: Task
    let onToggle: (Task, Bool) -> Void
    var onDelete: ((Task) -> Void)? = nil
    var onTaskUpdate: ((Task) -> Void)? = nil
    @State private var isCompleted: Bool
    @State private var showingDetail = false
    
    init(task: Task, onToggle: @escaping (Task, Bool) -> Void, onDelete: ((Task) -> Void)? = nil, onTaskUpdate: ((Task) -> Void)? = nil) {
        self.task = task
        self.onToggle = onToggle
        self.onDelete = onDelete
        self.onTaskUpdate = onTaskUpdate
        self._isCompleted = State(initialValue: task.isCompleted)
    }
    
    var body: some View {
        Button(action: {
            showingDetail = true
        }) {
            HStack(spacing: 12) {
                // Checkbox
                Button(action: {
                    isCompleted.toggle()
                    onToggle(task, isCompleted)
                }) {
                    ZStack {
                        Circle()
                            .stroke(Color(hex: task.subjectColor), lineWidth: 2)
                            .frame(width: 24, height: 24)
                        
                        if isCompleted {
                            Circle()
                                .fill(Color(hex: task.subjectColor))
                                .frame(width: 16, height: 16)
                            
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                // Task info
            VStack(alignment: .leading, spacing: 6) {
                // Title and priority
                HStack(spacing: 8) {
                    Text(task.title)
                        .font(.appBody)
                        .foregroundColor(.textPrimary)
                        .strikethrough(isCompleted, color: .textSecondary)
                    
                    Spacer()
                    
                    // Priority badge
                    Circle()
                        .fill(priorityColor)
                        .frame(width: 10, height: 10)
                }
                
                // Task type and due date
                HStack(spacing: 12) {
                    // Task type
                    HStack(spacing: 4) {
                        Image(systemName: taskTypeIcon)
                            .font(.system(size: 11))
                        Text(task.taskTypeDisplayLabel)
                            .font(.system(size: 11, weight: .medium))
                            .textCase(.uppercase)
                    }
                    .foregroundColor(.textSecondary)
                    
                    // Duration
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 11))
                        Text("\(task.durationDays)D")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(.textSecondary)
                    
                    Spacer()
                    
                    // Due date
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.system(size: 11))
                        Text(dueDateText)
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(dueDateColor)
                }
            }
        }
        .padding(12)
        .background(Color.bgSecondary)
        .cornerRadius(.cornerRadiusMedium)
        .overlay(
            RoundedRectangle(cornerRadius: .cornerRadiusMedium)
                .stroke(Color(hex: task.subjectColor).opacity(0.3), lineWidth: 1)
        )
        .opacity(isCompleted ? 0.6 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingDetail) {
            TaskDetailViewWrapper(
                task: task,
                onTaskCompletionChanged: { newCompletionState in
                    isCompleted = newCompletionState
                    onToggle(task, newCompletionState)
                },
                onTaskUpdated: { updatedTask in
                    onTaskUpdate?(updatedTask)
                },
                onDelete: {
                    onDelete?(task)
                }
            )
        }
    }
    
    private var priorityColor: Color {
        switch task.priority {
        case .critical: return .criticalRed
        case .important: return .importantYellow
        case .chill: return .chillGreen
        }
    }
    
    private var taskTypeIcon: String {
        switch task.taskType {
        case .exam, .midterm, .final: return "doc.text.fill"
        case .assignment: return "pencil"
        case .project: return "folder.fill"
        case .quiz: return "questionmark.circle.fill"
        case .homework: return "book.fill"
        case .reading: return "book"
        case .other: return "square.grid.2x2"
        }
    }
    
    private var dueDateText: String {
        let days = task.daysRemaining
        if days < 0 {
            return "OVERDUE"
        } else if days == 0 {
            return "TODAY"
        } else if days == 1 {
            return "TOMORROW"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"

            // Debug: Print the actual dueDate
            let debugFormatter = DateFormatter()
            debugFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            print("🔍 TaskListCard '\(task.title)' dueDate: \(debugFormatter.string(from: task.dueDate))")

            return formatter.string(from: task.dueDate).uppercased()
        }
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

// MARK: - To Do Today Card
struct ToDoTodayCard: View {
    let prioritizedMissions: [PrioritizedMiniMission]
    @ObservedObject var taskManager: TaskManager
    @ObservedObject var miniTaskManager: MiniTaskManager
    @State private var completedMissions: Set<UUID> = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("To Do Today")
                        .font(.appHeadline)
                        .foregroundColor(.textPrimary)
                    
                    Text("Prioritized intelligently")
                        .font(.appCaption)
                        .foregroundColor(.textSecondary)
                }
                
                Spacer()
                
                // Progress indicator
                ZStack {
                    Circle()
                        .stroke(Color.bgSecondary, lineWidth: 3)
                        .frame(width: 36, height: 36)
                    
                    Circle()
                        .trim(from: 0, to: CGFloat(completedMissions.count) / CGFloat(min(prioritizedMissions.count, 3)))
                        .stroke(Color.accentYellow, lineWidth: 3)
                        .frame(width: 36, height: 36)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut, value: completedMissions.count)
                    
                    Text("\(completedMissions.count)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.accentYellow)
                }
            }
            
            // Mini missions
            VStack(spacing: 10) {
                ForEach(prioritizedMissions.prefix(3)) { mission in
                    ToDoMiniMissionRow(
                        taskTitle: mission.taskTitle,
                        taskType: mission.taskType,
                        subjectCode: mission.subjectCode,
                        subjectColor: mission.subjectColor,
                        miniTask: mission.miniTask,
                        priorityScore: mission.priorityScore,
                        aiReasoning: mission.aiReasoning,
                        isCompleted: completedMissions.contains(mission.id),
                        onToggle: { isCompleted in
                            withAnimation(.spring(response: 0.3)) {
                                if isCompleted {
                                    completedMissions.insert(mission.id)
                                } else {
                                    completedMissions.remove(mission.id)
                                }
                                
                                // Sync with MiniTaskManager
                                let taskId = mission.taskId
                                miniTaskManager.toggleMiniTask(taskId: taskId, miniTaskId: mission.miniTask.id)
                                
                                // Check if all mini tasks are completed and update task
                                if let taskIndex = taskManager.tasks.firstIndex(where: { $0.id == taskId }) {
                                    if miniTaskManager.isTaskFullyCompleted(taskId: taskId) {
                                        taskManager.toggleTaskCompletion(taskManager.tasks[taskIndex], isCompleted: true)
                                    } else if !isCompleted {
                                        taskManager.toggleTaskCompletion(taskManager.tasks[taskIndex], isCompleted: false)
                                    }
                                }
                            }
                        }
                    )
                }
            }
            
            // Motivational message when all completed
            if completedMissions.count == min(prioritizedMissions.count, 3) && !prioritizedMissions.isEmpty {
                HStack {
                    Spacer()
                    
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.chillGreen)
                        
                        Text("Great work!")
                            .font(.appBodyBold)
                            .foregroundColor(.chillGreen)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.chillGreen.opacity(0.1))
                    .cornerRadius(20)
                    
                    Spacer()
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .sectionCard()
    }
}

// MARK: - To Do Mini Mission Row
struct ToDoMiniMissionRow: View {
    let taskTitle: String
    let taskType: TaskType
    let subjectCode: String
    let subjectColor: String
    let miniTask: MiniTask
    let priorityScore: Double
    let aiReasoning: String
    let isCompleted: Bool
    let onToggle: (Bool) -> Void
    @State private var showReasoning = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                // Checkbox
                Button(action: {
                    onToggle(!isCompleted)
                }) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color(hex: subjectColor), lineWidth: 2)
                            .frame(width: 24, height: 24)
                        
                        if isCompleted {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(hex: subjectColor))
                                .frame(width: 24, height: 24)
                            
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                }
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    // Mini mission title — always "Avance de (task)"
                    Text("Avance de \(taskTitle)")
                        .font(.appBody)
                        .foregroundColor(.textPrimary)
                        .strikethrough(isCompleted, color: .textSecondary)
                    
                    // Task context (subject + task title)
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color(hex: subjectColor))
                            .frame(width: 6, height: 6)
                        
                        Text("\(subjectCode) · \(taskTitle)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.textSecondary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        // Priority score badge
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 9))
                            Text("\(Int(priorityScore * 100))%")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundColor(priorityColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(priorityColor.opacity(0.15))
                        .cornerRadius(6)
                        
                        // Day badge
                        Text("Día \(miniTask.dayNumber)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Color(hex: subjectColor))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color(hex: subjectColor).opacity(0.15))
                            .cornerRadius(8)
                    }
                }
            }
            
            // AI Reasoning (expandable)
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showReasoning.toggle()
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 10))
                        .foregroundColor(.accentYellow)
                    
                    Text(showReasoning ? aiReasoning : "Ver por qué es prioritaria")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.textSecondary)
                        .lineLimit(showReasoning ? nil : 1)
                    
                    Spacer()
                    
                    Image(systemName: showReasoning ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.textSecondary)
                }
                .padding(.top, 4)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(12)
        .background(isCompleted ? Color.bgSecondary.opacity(0.5) : Color.bgSecondary)
        .cornerRadius(10)
        .opacity(isCompleted ? 0.7 : 1.0)
    }
    
    private var priorityColor: Color {
        if priorityScore >= 0.8 {
            return .criticalRed
        } else if priorityScore >= 0.6 {
            return .importantYellow
        } else {
            return .chillGreen
        }
    }
}

// MARK: - To Do Today Loading Card
struct ToDoTodayLoadingCard: View {
    @State private var isAnimating = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("To Do Today")
                        .font(.appHeadline)
                        .foregroundColor(.textPrimary)
                    
                    Text("Analyzing priorities...")
                        .font(.appCaption)
                        .foregroundColor(.textSecondary)
                }
                
                Spacer()
                
                // Loading spinner
                ProgressView()
                    .tint(.accentOrange)
            }
            
            // Loading placeholders
            VStack(spacing: 10) {
                ForEach(0..<3, id: \.self) { index in
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.textSecondary.opacity(0.2))
                            .frame(width: 24, height: 24)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.textSecondary.opacity(0.2))
                                .frame(height: 16)
                            
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.textSecondary.opacity(0.1))
                                .frame(width: 200, height: 12)
                        }
                    }
                    .padding(12)
                    .background(Color.bgSecondary)
                    .cornerRadius(10)
                    .opacity(isAnimating ? 0.5 : 1.0)
                    .animation(
                        .easeInOut(duration: 1.0)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.2),
                        value: isAnimating
                    )
                }
            }
        }
        .sectionCard()
        .onAppear {
            isAnimating = true
        }
    }
}

#Preview {
    TaskListView(
        taskManager: TaskManager(),
        subjectManager: SubjectManager()
    )
}
