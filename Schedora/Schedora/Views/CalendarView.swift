//
//  CalendarView.swift
//  Schedora
//
//  Monthly calendar view showing tasks as bars
//

import SwiftUI

struct CalendarView: View {
    let tasks: [Task]
    var onTaskToggle: ((Task, Bool) -> Void)?
    var onTaskDelete: ((Task) -> Void)?
    var onTaskUpdate: ((Task) -> Void)?
    
    @State private var currentMonth: Date = Date()
    @State private var selectedTask: Task? = nil
    
    private let calendar = Calendar.current
    private let daysOfWeek = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    
    // Get the first day of the current month
    private var firstDayOfMonth: Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonth))!
    }
    
    // Get the number of days in the current month
    private var numberOfDaysInMonth: Int {
        calendar.range(of: .day, in: .month, for: currentMonth)!.count
    }
    
    // Get the weekday of the first day (0 = Sunday)
    private var firstWeekday: Int {
        calendar.component(.weekday, from: firstDayOfMonth) - 1
    }
    
    // Get all days to display (including padding days from previous month)
    private var calendarDays: [CalendarDay] {
        var days: [CalendarDay] = []
        
        // Add padding days from previous month
        let previousMonth = calendar.date(byAdding: .month, value: -1, to: firstDayOfMonth)!
        let daysInPreviousMonth = calendar.range(of: .day, in: .month, for: previousMonth)!.count
        
        for i in 0..<firstWeekday {
            let day = daysInPreviousMonth - firstWeekday + i + 1
            let date = calendar.date(from: DateComponents(
                year: calendar.component(.year, from: previousMonth),
                month: calendar.component(.month, from: previousMonth),
                day: day
            ))!
            days.append(CalendarDay(date: date, isCurrentMonth: false))
        }
        
        // Add days of current month
        for day in 1...numberOfDaysInMonth {
            let date = calendar.date(from: DateComponents(
                year: calendar.component(.year, from: currentMonth),
                month: calendar.component(.month, from: currentMonth),
                day: day
            ))!
            days.append(CalendarDay(date: date, isCurrentMonth: true))
        }
        
        // Add padding days from next month to complete the grid
        let remainingDays = 42 - days.count // 6 rows × 7 days
        let nextMonth = calendar.date(byAdding: .month, value: 1, to: firstDayOfMonth)!
        
        for day in 1...remainingDays {
            let date = calendar.date(from: DateComponents(
                year: calendar.component(.year, from: nextMonth),
                month: calendar.component(.month, from: nextMonth),
                day: day
            ))!
            days.append(CalendarDay(date: date, isCurrentMonth: false))
        }
        
        return days
    }
    
    // Group tasks by their date range for display
    private func tasksForWeek(startingAt index: Int) -> [TaskBar] {
        let weekDays = Array(calendarDays[index..<min(index + 7, calendarDays.count)])
        guard let firstDay = weekDays.first?.date,
              let lastDay = weekDays.last?.date else { return [] }
        
        var taskBars: [TaskBar] = []
        
        for task in tasks {
            let taskStart = calendar.startOfDay(for: task.startDate)
            let taskEnd = calendar.startOfDay(for: task.dueDate)
            let weekStart = calendar.startOfDay(for: firstDay)
            let weekEnd = calendar.startOfDay(for: lastDay)
            
            // Check if task overlaps with this week
            if taskEnd >= weekStart && taskStart <= weekEnd {
                // Calculate start and end positions within the week
                var startCol = 0
                var endCol = 6
                
                for (i, day) in weekDays.enumerated() {
                    let dayDate = calendar.startOfDay(for: day.date)
                    if dayDate == taskStart || (taskStart < weekStart && i == 0) {
                        startCol = i
                    }
                    if dayDate == taskEnd || (taskEnd > weekEnd && i == 6) {
                        endCol = i
                    }
                }
                
                // Adjust if task starts before this week
                if taskStart < weekStart {
                    startCol = 0
                }
                
                // Adjust if task ends after this week
                if taskEnd > weekEnd {
                    endCol = 6
                }
                
                taskBars.append(TaskBar(
                    task: task,
                    startColumn: startCol,
                    endColumn: endCol,
                    continuesFromPrevious: taskStart < weekStart,
                    continuesToNext: taskEnd > weekEnd
                ))
            }
        }
        
        // Sort by start column and duration
        return taskBars.sorted { 
            if $0.startColumn != $1.startColumn {
                return $0.startColumn < $1.startColumn
            }
            return ($0.endColumn - $0.startColumn) > ($1.endColumn - $1.startColumn)
        }
    }
    
    var body: some View {
        ZStack {
            NotebookPaperBackground(showMargin: false)
            
            VStack(spacing: 0) {
                // Header
                calendarHeader
                
                // Calendar grid
                ScrollView {
                    VStack(spacing: 0) {
                        // Days of week header
                        daysOfWeekHeader
                        
                        // Calendar weeks
                        ForEach(0..<6, id: \.self) { weekIndex in
                            CalendarWeekRow(
                                days: Array(calendarDays[weekIndex * 7..<min((weekIndex + 1) * 7, calendarDays.count)]),
                                taskBars: tasksForWeek(startingAt: weekIndex * 7),
                                today: Date(),
                                onTaskTap: { task in
                                    selectedTask = task
                                }
                            )
                        }
                    }
                    .sectionCard(padding: 0)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                }
            }
        }
        .sheet(item: $selectedTask) { task in
            TaskDetailViewWrapper(
                task: task,
                onTaskCompletionChanged: { isCompleted in
                    onTaskToggle?(task, isCompleted)
                },
                onTaskUpdated: { updatedTask in
                    onTaskUpdate?(updatedTask)
                },
                onDelete: {
                    onTaskDelete?(task)
                }
            )
        }
    }
    
    // MARK: - Header
    private var calendarHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Calendar")
                    .font(.appTitle)
                    .foregroundColor(.textPrimary)
                
                Text(monthYearString)
                    .font(.appBody)
                    .foregroundColor(.textSecondary)
            }
            
            Spacer()
            
            // Navigation buttons
            HStack(spacing: 16) {
                Button(action: previousMonth) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.accentOrange)
                }
                
                Button(action: goToToday) {
                    Text("Today")
                        .font(.appCaptionBold)
                        .foregroundColor(.accentOrange)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.accentOrange.opacity(0.1))
                        .cornerRadius(8)
                }
                
                Button(action: nextMonth) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.accentOrange)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 16)
    }
    
    // MARK: - Days of Week Header
    private var daysOfWeekHeader: some View {
        HStack(spacing: 0) {
            ForEach(daysOfWeek, id: \.self) { day in
                Text(day)
                    .font(.appCaptionBold)
                    .foregroundColor(.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
        }
        .background(Color.bgSecondary)
    }
    
    // MARK: - Helpers
    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: currentMonth)
    }
    
    private func previousMonth() {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth)!
        }
    }
    
    private func nextMonth() {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth)!
        }
    }
    
    private func goToToday() {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentMonth = Date()
        }
    }
}

// MARK: - Calendar Day Model
struct CalendarDay: Identifiable {
    let id = UUID()
    let date: Date
    let isCurrentMonth: Bool
}

// MARK: - Task Bar Model
struct TaskBar: Identifiable {
    let id = UUID()
    let task: Task
    let startColumn: Int
    let endColumn: Int
    let continuesFromPrevious: Bool
    let continuesToNext: Bool
}

// MARK: - Calendar Week Row
struct CalendarWeekRow: View {
    let days: [CalendarDay]
    let taskBars: [TaskBar]
    let today: Date
    let onTaskTap: (Task) -> Void
    
    private let calendar = Calendar.current
    private let cellHeight: CGFloat = 100
    private let taskBarHeight: CGFloat = 22
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            // Day cells background
            HStack(spacing: 0) {
                ForEach(days) { day in
                    DayCell(
                        day: day,
                        isToday: calendar.isDateInToday(day.date)
                    )
                }
            }
            .frame(height: cellHeight)
            
            // Task bars overlaid
            VStack(alignment: .leading, spacing: 2) {
                Spacer()
                    .frame(height: 28) // Space for day number
                
                ForEach(Array(taskBars.prefix(3).enumerated()), id: \.element.id) { index, taskBar in
                    CalendarTaskBar(
                        taskBar: taskBar,
                        totalColumns: 7,
                        onTap: { onTaskTap(taskBar.task) }
                    )
                }
                
                // Show "+X more" if there are more tasks
                if taskBars.count > 3 {
                    Text("+\(taskBars.count - 3) more")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.textSecondary)
                        .padding(.leading, 4)
                }
                
                Spacer()
            }
            .frame(height: cellHeight)
        }
        
        // Border line
        Divider()
            .background(Color.notebookLine.opacity(0.5))
    }
}

// MARK: - Day Cell
struct DayCell: View {
    let day: CalendarDay
    let isToday: Bool
    
    private let calendar = Calendar.current
    
    var body: some View {
        VStack {
            HStack {
                Spacer()
                
                Text("\(calendar.component(.day, from: day.date))")
                    .font(.system(size: 14, weight: isToday ? .bold : .regular))
                    .foregroundColor(dayColor)
                    .frame(width: 24, height: 24)
                    .background(isToday ? Color.accentOrange : Color.clear)
                    .clipShape(Circle())
                
                Spacer()
            }
            .padding(.top, 4)
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(Color.clear)
        .overlay(
            Rectangle()
                .stroke(Color.notebookLine.opacity(0.3), lineWidth: 0.5)
        )
    }
    
    private var dayColor: Color {
        if isToday {
            return .white
        } else if day.isCurrentMonth {
            return .textPrimary
        } else {
            return .textTertiary
        }
    }
}

// MARK: - Calendar Task Bar
struct CalendarTaskBar: View {
    let taskBar: TaskBar
    let totalColumns: Int
    let onTap: () -> Void
    
    var body: some View {
        GeometryReader { geometry in
            let columnWidth = geometry.size.width / CGFloat(totalColumns)
            let barWidth = columnWidth * CGFloat(taskBar.endColumn - taskBar.startColumn + 1) - 4
            let barOffset = columnWidth * CGFloat(taskBar.startColumn) + 2
            
            Button(action: onTap) {
                HStack(spacing: 4) {
                    Text(taskBar.task.title)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Spacer(minLength: 0)
                    
                    Text(taskBar.task.subjectCode)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(4)
                }
                .padding(.horizontal, 6)
                .frame(width: barWidth, height: 20)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hex: taskBar.task.subjectColor))
                )
                .opacity(taskBar.task.isCompleted ? 0.5 : 1.0)
            }
            .buttonStyle(PlainButtonStyle())
            .offset(x: barOffset)
        }
        .frame(height: 22)
    }
}

// MARK: - Preview
#Preview {
    CalendarView(
        tasks: [
            Task(title: "Midterm Exam", taskType: .exam, priority: .critical,
                 dueDate: Date().addingTimeInterval(3 * 24 * 60 * 60),
                 subjectName: "Data Structures", subjectCode: "CSC373", subjectColor: "4ECDC4"),
            Task(title: "Assignment 2", taskType: .assignment, priority: .important,
                 dueDate: Date().addingTimeInterval(7 * 24 * 60 * 60),
                 subjectName: "Programming Languages", subjectCode: "CSC324", subjectColor: "E74C3C"),
            Task(title: "Quiz 3", taskType: .quiz, priority: .chill,
                 dueDate: Date().addingTimeInterval(1 * 24 * 60 * 60),
                 subjectName: "Linear Algebra", subjectCode: "MATH223", subjectColor: "9B59B6"),
        ]
    )
}
