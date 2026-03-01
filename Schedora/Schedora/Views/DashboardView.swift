//
//  DashboardView.swift
//  Schedora
//
//  Main dashboard with timeline view
//

import SwiftUI

struct DashboardView: View {
    @ObservedObject var taskManager: TaskManager
    @ObservedObject var subjectManager: SubjectManager
    @State private var selectedSubject: String? = nil
    @State private var showUploadPDF = false
    @State private var showEditSubject = false
    @State private var showAddSubject = false
    @State private var subjectToEdit: Subject? = nil

    var filteredTasks: [Task] {
        var tasks = taskManager.tasks.filter { !$0.isCompleted }
        if let selectedSubject = selectedSubject, selectedSubject != "ALL" {
            tasks = tasks.filter { $0.subjectCode == selectedSubject }
        }
        return tasks
    }
    
    var body: some View {
        ZStack {
            NotebookPaperBackground(showMargin: false)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header with upload button
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Schedora")
                                .font(.appTitle)
                                .foregroundColor(.textPrimary)

                            Text("One less thing to worry about")
                                .font(.appBody)
                                .foregroundColor(.textSecondary)
                        }

                        Spacer()

                        Button(action: { showUploadPDF = true }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.accentOrange)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 20)
                    
                    // Progress rings section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Subjects")
                            .font(.appHeadline)
                            .foregroundColor(.textPrimary)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(subjectManager.subjects) { subject in
                                    SubjectProgressCard(
                                        subject: subject,
                                        isSelected: selectedSubject == subject.code,
                                        onTap: {
                                            selectedSubject = subject.code
                                        },
                                        onLongPress: {
                                            // Don't allow editing "ALL"
                                            if subject.code != "ALL" {
                                                subjectToEdit = subject
                                                showEditSubject = true
                                            }
                                        }
                                    )
                                }
                                
                                // Add Subject Card
                                AddSubjectCard {
                                    showAddSubject = true
                                }
                            }
                        }
                    }
                    .sectionCard()
                    .padding(.horizontal)
                    
                    // Timeline section header — outside the card so it doesn't crowd the date axis
                    Text("Upcoming Deadlines")
                        .font(.appHeadline)
                        .foregroundColor(.textPrimary)
                        .padding(.horizontal)

                    // Notion-style horizontal timeline (no inner title padding)
                    VStack(alignment: .leading, spacing: 0) {
                        TimelineView(
                            tasks: filteredTasks.sorted(by: { $0.dueDate < $1.dueDate }),
                            onTaskToggle: { task, isCompleted in
                                // Handle task completion
                                taskManager.toggleTaskCompletion(task, isCompleted: isCompleted)
                                print("Task \(task.title) completed: \(isCompleted)")
                            },
                            onDurationChange: { task, newStartDate, newDueDate in
                                // Handle duration change from drag
                                taskManager.updateTaskDuration(task, newStartDate: newStartDate, newDueDate: newDueDate)
                                print("Task \(task.title) duration changed: \(newStartDate) to \(newDueDate)")
                            },
                            onTaskDelete: { task in
                                // Handle task deletion
                                taskManager.removeTask(task)
                                subjectManager.updateSubjectStats(for: taskManager.tasks)
                                print("Task \(task.title) deleted")
                            },
                            onTaskUpdate: { updatedTask in
                                // Handle any task update (priority, type, dates, etc.)
                                taskManager.updateTask(updatedTask)
                                print("Task \(updatedTask.title) updated")
                            }
                        )
                    }
                    .sectionCard()
                    .padding(.horizontal)
                    .padding(.bottom, 32)
                }
            }
        }
        .sheet(isPresented: $showUploadPDF) {
            UploadPDFView(onTasksCreated: { newTasks in
                // Add new tasks to the list
                taskManager.addTasks(newTasks)
                print("Added \(newTasks.count) tasks from PDF")
                
                // Auto-create subject if it doesn't exist yet
                if let firstTask = newTasks.first {
                    let code = firstTask.subjectCode
                    let alreadyExists = subjectManager.subjects.contains { $0.code.uppercased() == code.uppercased() }
                    if !alreadyExists {
                        subjectManager.addSubject(
                            name: firstTask.subjectName,
                            code: code,
                            color: firstTask.subjectColor
                        )
                        print("Created subject: \(firstTask.subjectName) (\(code))")
                    }
                }
            })
        }
        .sheet(isPresented: $showAddSubject) {
            EditSubjectView(
                subject: nil,
                onSave: { name, code, color in
                    subjectManager.addSubject(name: name, code: code, color: color)
                },
                onDelete: nil
            )
        }
        .sheet(isPresented: $showEditSubject) {
            if let subject = subjectToEdit {
                EditSubjectView(
                    subject: subject,
                    onSave: { name, code, color in
                        subjectManager.updateSubject(subject, name: name, code: code, color: color)
                    },
                    onDelete: {
                        subjectManager.deleteSubject(subject, taskManager: taskManager)
                    }
                )
            }
        }
        .onAppear {
            subjectManager.updateSubjectStats(for: taskManager.tasks)
        }
        .onChange(of: taskManager.tasks) { newTasks in
            subjectManager.updateSubjectStats(for: newTasks)
        }
    }
}

// MARK: - Add Subject Card
struct AddSubjectCard: View {
    let onTap: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            // Plus icon in circle
            ZStack {
                Circle()
                    .stroke(Color.textSecondary.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [5]))
                    .frame(width: 70, height: 70)
                
                Image(systemName: "plus")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(.textSecondary)
            }
            
            // Label
            VStack(spacing: 4) {
                Text("ADD")
                    .font(.appBodyBold)
                    .foregroundColor(.textSecondary)
                
                Text("Subject")
                    .font(.appCaption)
                    .foregroundColor(.textSecondary.opacity(0.7))
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 12)
        .background(Color.bgSecondary.opacity(0.5))
        .cornerRadius(.cornerRadiusMedium)
        .overlay(
            RoundedRectangle(cornerRadius: .cornerRadiusMedium)
                .stroke(Color.textSecondary.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [5]))
        )
        .onTapGesture {
            onTap()
        }
    }
}

#Preview {
    DashboardView(taskManager: TaskManager(), subjectManager: SubjectManager())
}
