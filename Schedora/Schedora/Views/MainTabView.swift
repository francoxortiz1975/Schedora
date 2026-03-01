//
//  MainTabView.swift
//  Schedora
//
//  Main container with bottom tab bar to switch between Timeline and Task List
//

import SwiftUI

enum AppView {
    case timeline
    case calendar
    case taskList
}

struct MainTabView: View {
    @StateObject private var taskManager = TaskManager()
    @StateObject private var subjectManager = SubjectManager()
    @State private var selectedView: AppView = .timeline
    @State private var showingAddTask = false

    var body: some View {
        ZStack {
            NotebookPaperBackground(showMargin: false)

            VStack(spacing: 0) {
                // Main content area
                ZStack {
                    // Timeline View
                    if selectedView == .timeline {
                        DashboardView(taskManager: taskManager, subjectManager: subjectManager)
                            .transition(.opacity)
                    }

                    // Calendar View
                    if selectedView == .calendar {
                        CalendarView(
                            tasks: taskManager.tasks.filter { !$0.isCompleted },
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
                        .transition(.opacity)
                    }

                    // Task List View
                    if selectedView == .taskList {
                        TaskListView(
                            taskManager: taskManager,
                            subjectManager: subjectManager
                        )
                        .transition(.opacity)
                    }
                }

                // Bottom Tab Bar
                BottomTabBar(
                    selectedView: $selectedView,
                    onAddTask: {
                        showingAddTask = true
                    }
                )
            }
            .sheet(isPresented: $showingAddTask) {
                AddTaskView(
                    taskManager: taskManager,
                    subjects: subjectManager.subjects.filter { $0.code != "ALL" }
                )
            }
        }
    }
}

// MARK: - Bottom Tab Bar
struct BottomTabBar: View {
    @Binding var selectedView: AppView
    let onAddTask: () -> Void
    
    var body: some View {
        HStack(spacing: 0) {
            // Timeline button
            TabBarButton(
                icon: "chart.bar.horizontal.page",
                title: "TIMELINE",
                isSelected: selectedView == .timeline,
                action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedView = .timeline
                    }
                }
            )
            
            // Calendar button
            TabBarButton(
                icon: "calendar",
                title: "CALENDAR",
                isSelected: selectedView == .calendar,
                action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedView = .calendar
                    }
                }
            )
            
            // Add button (center)
            Button(action: onAddTask) {
                ZStack {
                    Circle()
                        .fill(Color.accentYellow)
                        .frame(width: 56, height: 56)
                        .shadow(color: Color.accentYellow.opacity(0.5), radius: 10, x: 0, y: 5)
                    
                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                }
                .offset(y: -20)
            }
            .frame(maxWidth: .infinity)
            
            // Task List button
            TabBarButton(
                icon: "list.bullet.clipboard",
                title: "TASKS",
                isSelected: selectedView == .taskList,
                action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedView = .taskList
                    }
                }
            )
        }
        .frame(height: 70)
        .background(
            Color.bgSecondary
                .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: -5)
        )
        .ignoresSafeArea(edges: .bottom)
    }
}

// MARK: - Tab Bar Button
struct TabBarButton: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: isSelected ? .bold : .regular))
                    .foregroundColor(isSelected ? .accentYellow : .textSecondary)
                
                Text(title)
                    .font(.system(size: 10, weight: isSelected ? .bold : .medium))
                    .foregroundColor(isSelected ? .accentYellow : .textSecondary)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
    }
}

#Preview {
    MainTabView()
}
