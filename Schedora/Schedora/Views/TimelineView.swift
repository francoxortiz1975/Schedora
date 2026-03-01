//
//  TimelineView.swift
//  Schedora
//
//  Notion-style horizontal timeline with positioned task cards
//

import SwiftUI

struct TimelineView: View {
    let tasks: [Task]
    var onTaskToggle: ((Task, Bool) -> Void)?
    var onDurationChange: ((Task, Date, Date) -> Void)?
    var onTaskDelete: ((Task) -> Void)?
    var onTaskUpdate: ((Task) -> Void)?

    // Timeline configuration
    private let dayWidth: CGFloat = 120
    private let taskBlockHeight: CGFloat = 60
    private let taskBlockSpacing: CGFloat = 6
    private let startDate: Date
    private let semesterEndDate: Date

    init(tasks: [Task], onTaskToggle: ((Task, Bool) -> Void)? = nil, onDurationChange: ((Task, Date, Date) -> Void)? = nil, onTaskDelete: ((Task) -> Void)? = nil, onTaskUpdate: ((Task) -> Void)? = nil) {
        self.tasks = tasks
        self.onTaskToggle = onTaskToggle
        self.onDurationChange = onDurationChange
        self.onTaskDelete = onTaskDelete
        self.onTaskUpdate = onTaskUpdate

        // Semester end: June 15 of current year (or next year if already past June)
        var components = DateComponents()
        let currentYear = Calendar.current.component(.year, from: Date())
        let currentMonth = Calendar.current.component(.month, from: Date())
        components.year = currentMonth > 6 ? currentYear + 1 : currentYear
        components.month = 6
        components.day = 15
        self.semesterEndDate = Calendar.current.date(from: components) ?? Date()

        self.startDate = Calendar.current.startOfDay(for: Date())
    }

    // MARK: - Data

    private var daysToShow: Int {
        let days = Calendar.current.dateComponents([.day], from: startDate, to: semesterEndDate).day ?? 60
        return max(days + 5, 60)
    }

    private var totalContentWidth: CGFloat {
        CGFloat(daysToShow) * dayWidth
    }

    private var tasksBySubject: [String: [Task]] {
        Dictionary(grouping: tasks, by: { $0.subjectCode })
    }

    // Order subjects by nearest upcoming deadline first, overdue-only at bottom
    private var subjectOrder: [String] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        let subjectsWithDeadlines = tasksBySubject.map { (subjectCode, tasks) -> (String, Date, Bool) in
            let futureDueDates = tasks
                .map { $0.dueDate }
                .filter { calendar.startOfDay(for: $0) >= today }
            if let nearestFuture = futureDueDates.min() {
                return (subjectCode, nearestFuture, true)
            } else {
                let latestOverdue = tasks.map { $0.dueDate }.max() ?? Date.distantPast
                return (subjectCode, latestOverdue, false)
            }
        }

        return subjectsWithDeadlines
            .sorted { a, b in
                if a.2 == b.2 { return a.1 < b.1 }
                return a.2 && !b.2
            }
            .map { $0.0 }
    }

    // Greedy bin-packing: assign tasks to sub-rows with NO overlaps
    private func subRowsForSubject(_ subjectCode: String) -> [[Task]] {
        let subjectTasks = (tasksBySubject[subjectCode] ?? []).sorted { t1, t2 in
            if t1.startDate == t2.startDate { return t1.dueDate < t2.dueDate }
            return t1.startDate < t2.startDate
        }
        var subRows: [[Task]] = []
        for task in subjectTasks {
            var placed = false
            for i in 0..<subRows.count {
                if subRows[i].allSatisfy({ !tasksOverlap(task1: task, task2: $0) }) {
                    subRows[i].append(task)
                    placed = true
                    break
                }
            }
            if !placed {
                subRows.append([task])
            }
        }
        return subRows
    }

    // Height of one subject section (separator + padding + rows + padding)
    private func sectionHeight(for subjectCode: String) -> CGFloat {
        let rowCount = CGFloat(max(1, subRowsForSubject(subjectCode).count))
        return 1 + 8 + rowCount * (taskBlockHeight + taskBlockSpacing) + 8
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .topLeading) {
            scrollableTimeline
            stickySubjectLabels
        }
    }

    // MARK: - Sticky Subject Labels

    private var stickySubjectLabels: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Skip date header row (44 height + 8 spacing)
            Color.clear.frame(height: 52)

            ForEach(subjectOrder, id: \.self) { subjectCode in
                if let firstTask = tasksBySubject[subjectCode]?.first {
                    VStack(alignment: .leading, spacing: 0) {
                        // Offset past separator(1) + padding(8)
                        Color.clear.frame(height: 9)
                        Text(subjectCode)
                            .font(.appCaptionBold)
                            .foregroundColor(Color(hex: firstTask.subjectColor))
                            .padding(.vertical, 4)
                            .padding(.horizontal, 6)
                            .background(Color.bgPrimary.opacity(0.85))
                            .cornerRadius(4)
                        Spacer(minLength: 0)
                    }
                    .frame(height: sectionHeight(for: subjectCode))
                }
            }
        }
        .padding(.leading, 8)
        .allowsHitTesting(false)
    }

    // MARK: - Scrollable Timeline

    private var scrollableTimeline: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    // Leading padding so today is visible
                    Color.clear
                        .frame(width: UIScreen.main.bounds.width / 2 - 60)

                    ZStack(alignment: .topLeading) {
                        // Background vertical grid lines
                        TimelineGrid(
                            startDate: startDate,
                            daysToShow: daysToShow,
                            dayWidth: dayWidth,
                            semesterEndDate: semesterEndDate
                        )

                        // Main vertical content: date headers + subject rows
                        VStack(alignment: .leading, spacing: 0) {
                            timelineDateHeaders

                            ForEach(subjectOrder, id: \.self) { subjectCode in
                                subjectSection(for: subjectCode)
                            }
                        }

                        // Today marker — align to leading edge of today's column
                        TodayMarker()
                            .frame(width: dayWidth, alignment: .leading)
                            .offset(x: xPosition(for: Date()))
                            .id("today")

                        // Semester end marker
                        SemesterEndMarker()
                            .frame(width: dayWidth, alignment: .leading)
                            .offset(x: xPosition(for: semesterEndDate))
                    }

                    // Trailing padding
                    Color.clear.frame(width: 100)
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        proxy.scrollTo("today", anchor: .leading)
                    }
                }
            }
        }
    }

    // MARK: - Subject Section (one row per subject with sub-rows)

    @ViewBuilder
    private func subjectSection(for subjectCode: String) -> some View {
        let subRows = subRowsForSubject(subjectCode)

        VStack(alignment: .leading, spacing: 0) {
            // Separator line
            Rectangle()
                .fill(Color.textSecondary.opacity(0.15))
                .frame(width: totalContentWidth, height: 1)

            // Top padding
            Color.clear.frame(height: 8)

            // Sub-rows of tasks
            ForEach(0..<max(1, subRows.count), id: \.self) { rowIndex in
                ZStack(alignment: .leading) {
                    // Invisible spacer ensures full width + height
                    Color.clear
                        .frame(width: totalContentWidth, height: taskBlockHeight)

                    if rowIndex < subRows.count {
                        ForEach(subRows[rowIndex]) { task in
                            TimelineTaskBlock(
                                task: task,
                                dayWidth: dayWidth,
                                onToggle: onTaskToggle,
                                onDurationChange: onDurationChange,
                                onDelete: onTaskDelete,
                                onTaskUpdate: onTaskUpdate
                            )
                            .offset(x: xPosition(for: task.startDate))
                        }
                    }
                }
                .padding(.bottom, taskBlockSpacing)
            }

            // Bottom padding
            Color.clear.frame(height: 8)
        }
    }

    // MARK: - Date Headers

    private var timelineDateHeaders: some View {
        HStack(alignment: .bottom, spacing: 0) {
            ForEach(0..<daysToShow, id: \.self) { day in
                let currentDate = Calendar.current.date(byAdding: .day, value: day, to: startDate)!
                let isToday = Calendar.current.isDateInToday(currentDate)
                let isSemesterEnd = Calendar.current.isDate(currentDate, inSameDayAs: semesterEndDate)
                let shouldShow = shouldShowDateLabel(for: day, isSemesterEnd: isSemesterEnd)

                VStack(spacing: 4) {
                    if shouldShow {
                        Text(formatDateLabel(for: day, date: currentDate, isSemesterEnd: isSemesterEnd))
                            .font(.system(size: isToday ? 13 : 12, weight: isToday || isSemesterEnd ? .bold : .semibold))
                            .foregroundColor(.black)

                        Circle()
                            .fill(isToday || isSemesterEnd ? Color.accentYellow : Color.black.opacity(0.3))
                            .frame(width: isToday ? 8 : 6, height: isToday ? 8 : 6)
                    } else {
                        Spacer()
                    }
                }
                .frame(width: dayWidth, height: 44)
            }
        }
    }

    // MARK: - Helpers

    private func shouldShowDateLabel(for day: Int, isSemesterEnd: Bool) -> Bool {
        // Show date on every column
        return true
    }

    private func formatDateLabel(for daysAhead: Int, date: Date, isSemesterEnd: Bool) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let targetDate = calendar.startOfDay(for: date)

        if isSemesterEnd { return "DEC 20" }
        if calendar.isDate(targetDate, inSameDayAs: today) { return "TODAY" }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: today),
           calendar.isDate(targetDate, inSameDayAs: tomorrow) { return "TMRW" }

        let daysDiff = calendar.dateComponents([.day], from: today, to: targetDate).day ?? 0
        if daysDiff >= 0 && daysDiff <= 6 {
            formatter.dateFormat = "EEE"
            return formatter.string(from: date).uppercased()
        } else {
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date).uppercased()
        }
    }

    // X position based on date
    private func xPosition(for date: Date) -> CGFloat {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: startDate), to: startOfDay).day ?? 0
        return CGFloat(days) * dayWidth
    }

    // Check if two tasks overlap in their date ranges
    private func tasksOverlap(task1: Task, task2: Task) -> Bool {
        let calendar = Calendar.current
        let start1 = calendar.startOfDay(for: task1.startDate)
        let end1 = calendar.startOfDay(for: task1.dueDate)
        let start2 = calendar.startOfDay(for: task2.startDate)
        let end2 = calendar.startOfDay(for: task2.dueDate)
        return start1 <= end2 && end1 >= start2
    }
}

// MARK: - Timeline Grid (vertical date lines)
struct TimelineGrid: View {
    let startDate: Date
    let daysToShow: Int
    let dayWidth: CGFloat
    let semesterEndDate: Date
    
    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(0..<daysToShow, id: \.self) { day in
                let currentDate = Calendar.current.date(byAdding: .day, value: day, to: startDate)!
                let isToday = Calendar.current.isDateInToday(currentDate)
                let isSemesterEnd = Calendar.current.isDate(currentDate, inSameDayAs: semesterEndDate)
                
                VStack(alignment: .leading, spacing: 0) {
                    // Vertical line for day division
                    // Don't draw lines for today or semester end (they have their own markers)
                    if !isToday && !isSemesterEnd {
                        Rectangle()
                            .fill(Color.textSecondary.opacity(0.15))
                            .frame(width: 1)
                    }
                }
                .frame(width: dayWidth, alignment: .leading)
            }
        }
    }
}

// MARK: - Timeline Axis (horizontal line with date markers)
struct TimelineAxis: View {
    let startDate: Date
    let daysToShow: Int
    let dayWidth: CGFloat
    let semesterEndDate: Date
    
    var body: some View {
        VStack(spacing: 0) {
            // Date labels row
            HStack(alignment: .top, spacing: 0) {
                ForEach(0..<daysToShow, id: \.self) { day in
                    let currentDate = Calendar.current.date(byAdding: .day, value: day, to: startDate)!
                    let isToday = Calendar.current.isDateInToday(currentDate)
                    let isSemesterEnd = Calendar.current.isDate(currentDate, inSameDayAs: semesterEndDate)
                    let shouldShow = shouldShowLabel(for: day, isSemesterEnd: isSemesterEnd)
                    
                    if shouldShow {
                        VStack(spacing: 6) {
                            // Date label
                            Text(dateLabel(for: day, date: currentDate, isSemesterEnd: isSemesterEnd))
                                .font(isToday || isSemesterEnd ? .system(size: 14, weight: .bold) : .system(size: 13, weight: .semibold))
                                .foregroundColor(.black)
                                .frame(width: dayWidth, alignment: .center)
                            
                            // Marker dot
                            Circle()
                                .fill(
                                    isSemesterEnd ? Color.accentYellow :
                                    isToday ? Color.accentYellow :
                                    Color.black.opacity(0.4)
                                )
                                .frame(width: isSemesterEnd ? 12 : isToday ? 10 : 8, height: isSemesterEnd ? 12 : isToday ? 10 : 8)
                            
                            // Special label for semester end
                            if isSemesterEnd {
                                Text("🎯 META")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.accentYellow)
                                    .frame(width: dayWidth, alignment: .center)
                            }
                        }
                        .frame(height: 100) // Axis row height
                    } else {
                        // Empty spacer for days without labels
                        Color.clear
                            .frame(width: dayWidth, height: 100)
                    }
                }
            }
            
            // Horizontal timeline line
            Rectangle()
                .fill(Color.textSecondary.opacity(0.3))
                .frame(height: 2)
        }
        .background(Color.bgPrimary)
        .clipped() // Prevent bleed into task area
    }
    
    // Determine which days should show labels
    private func shouldShowLabel(for day: Int, isSemesterEnd: Bool) -> Bool {
        if isSemesterEnd { return true } // Always show semester end
        if day == 0 { return true } // Always show today
        if day == 1 { return true } // Always show tomorrow
        if day <= 7 { return true } // Show first week daily
        if day % 7 == 0 { return true } // Then every 7 days
        return false
    }
    
    private func dateLabel(for daysAhead: Int, date: Date, isSemesterEnd: Bool) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let targetDate = calendar.startOfDay(for: date)
        
        if isSemesterEnd {
            return "DEC 20"
        }
        
        // Check if date is today based on actual calendar date
        if calendar.isDate(targetDate, inSameDayAs: today) {
            return "TODAY"
        }
        
        // Check if date is tomorrow
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: today),
           calendar.isDate(targetDate, inSameDayAs: tomorrow) {
            return "TOMORROW"
        }
        
        // For dates within next 6 days, show day name
        let daysDiff = calendar.dateComponents([.day], from: today, to: targetDate).day ?? 0
        if daysDiff >= 0 && daysDiff <= 6 {
            formatter.dateFormat = "EEEE"
            let dayName = formatter.string(from: date)
            // Get first 3 letters (SAT, SUN, MON, etc.)
            return String(dayName.prefix(3)).uppercased()
        } else {
            // For farther dates, show month and day
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date).uppercased()
        }
    }
}

// MARK: - Timeline Task Block (duration block, Gantt-style)
struct TimelineTaskBlock: View {
    let task: Task
    let dayWidth: CGFloat
    var onToggle: ((Task, Bool) -> Void)?
    var onDurationChange: ((Task, Date, Date) -> Void)?
    var onDelete: ((Task) -> Void)?
    var onTaskUpdate: ((Task) -> Void)?
    @State private var isCompleted: Bool
    @State private var isDraggingLeft = false
    @State private var isDraggingRight = false
    @State private var tempStartDate: Date?
    @State private var tempDueDate: Date?
    @State private var showingDetail = false
    
    init(task: Task, dayWidth: CGFloat, onToggle: ((Task, Bool) -> Void)? = nil, onDurationChange: ((Task, Date, Date) -> Void)? = nil, onDelete: ((Task) -> Void)? = nil, onTaskUpdate: ((Task) -> Void)? = nil) {
        self.task = task
        self.dayWidth = dayWidth
        self.onToggle = onToggle
        self.onDurationChange = onDurationChange
        self.onDelete = onDelete
        self.onTaskUpdate = onTaskUpdate
        self._isCompleted = State(initialValue: task.isCompleted)
    }
    
    private let calendar = Calendar.current
    
    // Calculate width based on task duration (fill complete days)
    private var blockWidth: CGFloat {
        let baseWidth = CGFloat(task.durationDays) * dayWidth
        // Ensure minimum width of one day
        return max(dayWidth, baseWidth)
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Left edge handle (extend duration backwards - changes startDate, keeps dueDate)
            ZStack(alignment: .leading) {
                // Touch area highlight (shows on drag)
                if isDraggingLeft {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.accentYellow.opacity(0.3))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                // Visual handle bar on the leading edge
                Rectangle()
                    .fill(Color(hex: task.subjectColor))
                    .frame(width: isDraggingLeft ? 6 : 4)
                    .animation(.easeOut(duration: 0.15), value: isDraggingLeft)
            }
            .frame(width: 20, height: 60)
            .contentShape(Rectangle())
            .highPriorityGesture(
                DragGesture(minimumDistance: 5)
                    .onChanged { value in
                        if !isDraggingLeft {
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()
                        }
                        isDraggingLeft = true

                        let days = round(value.translation.width / dayWidth)
                        if let newStart = calendar.date(byAdding: .day, value: Int(days), to: task.startDate) {
                            tempStartDate = calendar.startOfDay(for: newStart)
                        }
                    }
                    .onEnded { value in
                        isDraggingLeft = false
                        if let newStart = tempStartDate, newStart < task.dueDate {
                            let normalizedStart = calendar.startOfDay(for: newStart)
                            // Only fire if the date actually changed
                            if normalizedStart != calendar.startOfDay(for: task.startDate) {
                                onDurationChange?(task, normalizedStart, task.dueDate)
                            }
                        }
                        tempStartDate = nil
                    }
            )

            // Task block content
            ZStack(alignment: .leading) {
                taskContentView
                    .padding(8)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        showingDetail = true
                    }
            }

            // Right edge handle (extend duration forward - keeps startDate, changes dueDate)
            ZStack(alignment: .trailing) {
                // Touch area highlight (shows on drag)
                if isDraggingRight {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.accentYellow.opacity(0.3))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                // Visual handle bar on the trailing edge
                Rectangle()
                    .fill(Color(hex: task.subjectColor))
                    .frame(width: isDraggingRight ? 6 : 4)
                    .animation(.easeOut(duration: 0.15), value: isDraggingRight)
            }
            .frame(width: 20, height: 60)
            .contentShape(Rectangle())
            .highPriorityGesture(
                DragGesture(minimumDistance: 5)
                    .onChanged { value in
                        if !isDraggingRight {
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()
                        }
                        isDraggingRight = true

                        let days = round(value.translation.width / dayWidth)
                        if let newDue = calendar.date(byAdding: .day, value: Int(days), to: task.dueDate) {
                            tempDueDate = calendar.startOfDay(for: newDue)
                        }
                    }
                    .onEnded { value in
                        isDraggingRight = false
                        if let newDue = tempDueDate, newDue > task.startDate {
                            let normalizedDue = calendar.startOfDay(for: newDue)
                            // Only fire if the date actually changed
                            if normalizedDue != calendar.startOfDay(for: task.dueDate) {
                                onDurationChange?(task, task.startDate, normalizedDue)
                            }
                        }
                        tempDueDate = nil
                    }
            )
        }
        .frame(width: blockWidth, height: 60)
        .background(Color(hex: task.subjectColor).opacity(0.15))
        .cornerRadius(.cornerRadiusMedium)
        .overlay(
            RoundedRectangle(cornerRadius: .cornerRadiusMedium)
                .stroke(Color(hex: task.subjectColor).opacity(0.5), lineWidth: 1)
        )
        .opacity(isCompleted ? 0.5 : 1.0)
        .shadow(color: Color.black.opacity(0.15), radius: 6, x: 0, y: 3)
        .sheet(isPresented: $showingDetail) {
            TaskDetailViewWrapper(
                task: task,
                onTaskCompletionChanged: { newCompletionState in
                    isCompleted = newCompletionState
                    onToggle?(task, newCompletionState)
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
    
    private var dueDateColor: Color {
        let days = task.daysRemaining
        if days < 0 {
            return .criticalRed
        } else if days <= 3 {
            return .importantYellow
        } else if task.shouldBeStarted {
            return .chillGreen
        } else {
            return .textSecondary
        }
    }

    // Task content view (reusable for both main and ghost)
    private var taskContentView: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Header with title and priority
            HStack(spacing: 8) {
                // Task title (no subject code, it's in the row label)
                Text(task.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.textPrimary)
                    .lineLimit(1)

                Spacer(minLength: 4)

                // Priority indicator
                Circle()
                    .fill(priorityColor)
                    .frame(width: 8, height: 8)
            }

            // Footer with task type and duration
            HStack(spacing: 8) {
                Text(task.taskTypeDisplayLabel)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.textSecondary)
                    .textCase(.uppercase)

                Spacer()

                // Duration indicator
                HStack(spacing: 2) {
                    Image(systemName: "clock")
                        .font(.system(size: 9))
                    Text("\(task.durationDays)D")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundColor(dueDateColor)
            }
        }
    }
}

// MARK: - Timeline Task Card (compact version for timeline)
struct TimelineTaskCard: View {
    let task: Task
    var onToggle: ((Task, Bool) -> Void)?
    @State private var isCompleted: Bool
    
    init(task: Task, onToggle: ((Task, Bool) -> Void)? = nil) {
        self.task = task
        self.onToggle = onToggle
        self._isCompleted = State(initialValue: task.isCompleted)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Subject code and checkbox
            HStack {
                Button(action: {
                    isCompleted.toggle()
                    onToggle?(task, isCompleted)
                }) {
                    ZStack {
                        Circle()
                            .stroke(Color(hex: task.subjectColor), lineWidth: 2)
                            .frame(width: 20, height: 20)
                        
                        if isCompleted {
                            Circle()
                                .fill(Color(hex: task.subjectColor))
                                .frame(width: 12, height: 12)
                        }
                    }
                }
                
                Text(task.subjectCode)
                    .font(.appCaptionBold)
                    .foregroundColor(Color(hex: task.subjectColor))
                    .textCase(.uppercase)
                
                Spacer()
                
                // Priority indicator
                Circle()
                    .fill(priorityColor)
                    .frame(width: 10, height: 10)
            }
            
            // Task title
            Text(task.title)
                .font(.appBodyBold)
                .foregroundColor(.textPrimary)
                .lineLimit(2)
            
            // Task type
            Text(task.taskTypeDisplayLabel)
                .font(.appCaption)
                .foregroundColor(.textSecondary)
                .textCase(.uppercase)
            
            // Due date info
            HStack(spacing: 4) {
                Image(systemName: "calendar")
                    .font(.system(size: 10))
                Text(dueDateText)
                    .font(.appCaption)
            }
            .foregroundColor(dueDateColor)
            
            Spacer()
        }
        .padding(12)
        .frame(width: 160, height: 160)
        .background(Color.bgSecondary)
        .cornerRadius(.cornerRadiusMedium)
        .overlay(
            RoundedRectangle(cornerRadius: .cornerRadiusMedium)
                .stroke(Color(hex: task.subjectColor), lineWidth: 2)
        )
        .opacity(isCompleted ? 0.5 : 1.0)
        .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
    }
    
    private var priorityColor: Color {
        switch task.priority {
        case .critical: return .criticalRed
        case .important: return .importantYellow
        case .chill: return .chillGreen
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
            return "\(days)D"
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

// MARK: - Semester End Marker (Goal Line)
struct SemesterEndMarker: View {
    var body: some View {
        VStack(spacing: 8) {
            // Goal flag icon
            ZStack {
                Circle()
                    .fill(Color.accentOrange)
                    .frame(width: 40, height: 40)
                
                Image(systemName: "flag.checkered")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
            }
            
            // Vertical goal line
            Rectangle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.accentYellow,
                            Color.accentYellow.opacity(0.5),
                            Color.accentYellow.opacity(0.1)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 3, height: 400)
            
            // Label
            Text("FIN DE\nSEMESTRE")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.accentYellow)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color.bgSecondary)
                .cornerRadius(6)
        }
    }
}

// MARK: - Today Marker (Current Day Line)
struct TodayMarker: View {
    var body: some View {
        VStack(spacing: 8) {
            // Today indicator icon
            ZStack {
                Circle()
                    .fill(Color.accentOrange.opacity(0.8))
                    .frame(width: 32, height: 32)
                
                Image(systemName: "calendar.circle.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
            }
            
            // Vertical line for today
            Rectangle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.accentYellow.opacity(0.8),
                            Color.accentYellow.opacity(0.4),
                            Color.accentYellow.opacity(0.1)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 2, height: 400)
            
            // Label
            Text("TODAY")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.accentYellow)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.bgSecondary)
                .cornerRadius(6)
        }
    }
}

#Preview {
    ZStack {
        NotebookPaperBackground(showMargin: false)
        
        TimelineView(tasks: [
            Task(title: "Midterm Exam", taskType: .exam, priority: .critical,
                 dueDate: Date().addingTimeInterval(3 * 24 * 60 * 60),
                 subjectName: "Data Structures", subjectCode: "CSC373", subjectColor: "4ECDC4"),
            Task(title: "Assignment 2", taskType: .assignment, priority: .important,
                 dueDate: Date().addingTimeInterval(7 * 24 * 60 * 60),
                 subjectName: "Programming Languages", subjectCode: "CSC324", subjectColor: "FF6B6B"),
            Task(title: "Quiz 3", taskType: .quiz, priority: .chill,
                 dueDate: Date().addingTimeInterval(10 * 24 * 60 * 60),
                 subjectName: "Linear Algebra", subjectCode: "MATH223", subjectColor: "FFE66D"),
            Task(title: "Final Project", taskType: .project, priority: .important,
                 dueDate: Date().addingTimeInterval(25 * 24 * 60 * 60),
                 subjectName: "Programming Languages", subjectCode: "CSC324", subjectColor: "FF6B6B"),
        ])
    }
}
