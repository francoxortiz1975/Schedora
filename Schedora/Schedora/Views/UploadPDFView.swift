//
//  UploadPDFView.swift
//  Schedora
//
//  PDF upload and processing view
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - Upload State
enum UploadState {
    case idle
    case processing(progress: Double, message: String)
    case success(taskCount: Int)
    case error(String)
}

struct UploadPDFView: View {
    @Environment(\.dismiss) var dismiss
    @State private var uploadState: UploadState = .idle
    @State private var showDocumentPicker = false
    @State private var selectedFileName: String = ""
    @State private var parsedTasks: [Task] = []

    // Callback to pass tasks back to parent view
    var onTasksCreated: ([Task]) -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                NotebookPaperBackground(showMargin: false)

                VStack(spacing: 32) {
                    // Header
                    headerView

                    // Main content based on state
                    switch uploadState {
                    case .idle:
                        uploadZoneView
                    case .processing(let progress, let message):
                        processingView(progress: progress, message: message)
                    case .success(let taskCount):
                        successView(taskCount: taskCount)
                    case .error(let message):
                        errorView(message: message)
                    }

                    Spacer()
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.textPrimary)
                    }
                }
            }
            .fileImporter(
                isPresented: $showDocumentPicker,
                allowedContentTypes: [.pdf],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    
                    // Get file name
                    selectedFileName = url.lastPathComponent
                    
                    // Read data with security scoped resource
                    guard url.startAccessingSecurityScopedResource() else {
                        uploadState = .error("Could not access file. Please try again.")
                        return
                    }
                    
                    defer { url.stopAccessingSecurityScopedResource() }
                    
                    do {
                        let data = try Data(contentsOf: url)
                        processPDF(data: data, fileName: selectedFileName)
                    } catch {
                        uploadState = .error("Could not read file: \(error.localizedDescription)")
                    }
                    
                case .failure(let error):
                    uploadState = .error("File selection failed: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Header
    private var headerView: some View {
        VStack(spacing: 8) {
            Text("DROP YOUR SYLLABUS")
                .font(.appTitle)
                .foregroundColor(.textPrimary)
                .fontWeight(.bold)

            Text("We'll extract all your deadlines automatically")
                .font(.appBody)
                .foregroundColor(.textSecondary)
        }
    }

    // MARK: - Upload Zone
    private var uploadZoneView: some View {
        VStack(spacing: 24) {
            // Drop zone
            Button(action: { showDocumentPicker = true }) {
                VStack(spacing: 16) {
                    Image(systemName: "doc.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.accentOrange)

                    VStack(spacing: 4) {
                        Text("Tap to browse")
                            .font(.appBodyBold)
                            .foregroundColor(.textPrimary)

                        Text("PDF files only")
                            .font(.appCaption)
                            .foregroundColor(.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 250)
                .background(Color.bgSecondary)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.accentOrange.opacity(0.3), lineWidth: 2)
                        .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [10, 5]))
                )
            }

            // Upload button
            Button(action: { showDocumentPicker = true }) {
                Text("+ ADD SYLLABUS")
                    .font(.appButton)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentOrange)
                    .cornerRadius(8)
            }
        }
    }

    // MARK: - Processing View
    private func processingView(progress: Double, message: String) -> some View {
        VStack(spacing: 24) {
            ProgressView(value: progress, total: 1.0)
                .progressViewStyle(LinearProgressViewStyle(tint: .accentOrange))
                .scaleEffect(x: 1, y: 2, anchor: .center)

            Text(message)
                .font(.appBodyBold)
                .foregroundColor(.textPrimary)

            Text("\(Int(progress * 100))%")
                .font(.appHeadline)
                .foregroundColor(.accentOrange)
        }
        .padding(32)
        .background(Color.bgSecondary)
        .cornerRadius(16)
    }

    // MARK: - Success View
    private func successView(taskCount: Int) -> some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.chillGreen)

            Text("FOUND \(taskCount) TASKS")
                .font(.appTitle)
                .foregroundColor(.textPrimary)
                .fontWeight(.bold)

            VStack(spacing: 12) {
                Button(action: {
                    onTasksCreated(parsedTasks)
                    dismiss()
                }) {
                    Text("VIEW TIMELINE")
                        .font(.appButton)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentOrange)
                        .cornerRadius(8)
                }

                Button(action: {
                    uploadState = .idle
                    parsedTasks = []
                }) {
                    Text("UPLOAD ANOTHER")
                        .font(.appButton)
                        .foregroundColor(.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.bgSecondary)
                        .cornerRadius(12)
                }
            }
        }
        .padding(32)
    }

    // MARK: - Error View
    private func errorView(message: String) -> some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 80))
                .foregroundColor(.criticalRed)

            Text("OOPS!")
                .font(.appTitle)
                .foregroundColor(.textPrimary)
                .fontWeight(.bold)

            Text(message)
                .font(.appBody)
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)

            Button(action: { uploadState = .idle }) {
                Text("TRY AGAIN")
                    .font(.appButton)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentOrange)
                    .cornerRadius(8)
            }
        }
        .padding(32)
    }

    // MARK: - Process PDF
    private func processPDF(data: Data, fileName: String) {
        uploadState = .processing(progress: 0.0, message: "Opening PDF...")

        _Concurrency.Task {
            do {
                // Step 1: Extract text from PDF
                let processed = try await PDFProcessingService.shared.processPDF(
                    data: data,
                    fileName: fileName
                ) { progress, message in
                    DispatchQueue.main.async {
                        self.uploadState = .processing(progress: progress, message: message)
                    }
                }

                // Update progress
                await MainActor.run {
                    uploadState = .processing(progress: 0.7, message: "Parsing with AI...")
                }

                // Step 2: Parse syllabus with Gemini
                await parseWithGemini(
                    text: processed.extractedText,
                    subjectCode: processed.detectedSubjectCode,
                    subjectName: processed.detectedSubjectName,
                    fileName: fileName
                )

            } catch {
                await MainActor.run {
                    uploadState = .error("Could not read PDF. Make sure it's a valid file.")
                }
            }
        }
    }

    // MARK: - Parse with Gemini
    private func parseWithGemini(
        text: String,
        subjectCode: String?,
        subjectName: String?,
        fileName: String
    ) async {
        GeminiService.shared.parseSyllabus(text: text, subjectCode: subjectCode) { result in
            switch result {
            case .success(let response):
                // Determine final subject info
                let finalSubjectCode = response.subjectCode ?? subjectCode ?? "UNKNOWN"
                let finalSubjectName = response.subjectName ?? subjectName ?? fileName

                // Assign a color (you can make this smarter with a color pool)
                let subjectColor = assignSubjectColor()

                // Convert parsed tasks to Task models
                let tasks = response.tasks.compactMap { parsedTask in
                    GeminiService.shared.convertToTask(
                        parsedTask: parsedTask,
                        subjectCode: finalSubjectCode,
                        subjectName: finalSubjectName,
                        subjectColor: subjectColor
                    )
                }

                if tasks.isEmpty {
                    uploadState = .error("No tasks found in the syllabus. Try a different file.")
                } else {
                    parsedTasks = tasks
                    uploadState = .success(taskCount: tasks.count)
                }

            case .failure(let error):
                uploadState = .error("AI parsing failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Assign Subject Color
    private func assignSubjectColor() -> String {
        let colors = [
            "E74C3C", // Red marker
            "3498DB", // Blue marker
            "9B59B6", // Purple marker
            "27AE60", // Green marker
            "E67E22", // Orange marker
            "1ABC9C", // Teal marker
            "F1C40F", // Yellow highlighter
            "E91E63"  // Pink marker
        ]

        // Randomly assign for now
        return colors.randomElement() ?? "FF6B6B"
    }
}

#Preview {
    UploadPDFView(onTasksCreated: { tasks in
        print("Created \(tasks.count) tasks")
    })
}
