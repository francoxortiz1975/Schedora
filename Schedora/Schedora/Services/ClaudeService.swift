//
//  ClaudeService.swift
//  Schedora
//
//  Service to integrate with Claude API for intelligent task prioritization
//

import Foundation

// MARK: - Claude API Configuration
struct ClaudeConfig {
    // ⚠️ Set your API key in environment variable or replace at build time
    static let apiKey = ProcessInfo.processInfo.environment["CLAUDE_API_KEY"] ?? ""
    static let apiURL = "https://api.anthropic.com/v1/messages"
    static let model = "claude-sonnet-4-5-20250929" // Claude 4.5 Sonnet (latest, best for coding/agents)
    static let maxTokens = 4096
}

// MARK: - Claude API Models
struct ClaudeRequest: Codable {
    let model: String
    let max_tokens: Int
    let messages: [ClaudeMessage]
    let system: String?
}

struct ClaudeMessage: Codable {
    let role: String
    let content: String
}

struct ClaudeResponse: Codable {
    let id: String
    let type: String
    let role: String
    let content: [ClaudeContent]
    let model: String
    let stop_reason: String?
}

struct ClaudeContent: Codable {
    let type: String
    let text: String
}

// MARK: - Parsed Task from Syllabus
struct ParsedTask: Codable {
    let title: String
    let type: String // exam/midterm/final/assignment/project/quiz/reading/homework
    let dueDate: String? // ISO 8601 format YYYY-MM-DD
    let weight: String?
    let notes: String?
}

struct SyllabusParseResponse: Codable {
    let tasks: [ParsedTask]
    let subjectName: String?
    let subjectCode: String?
}

// MARK: - Prioritized Mini Mission
struct PrioritizedMiniMission: Identifiable {
    let id: UUID
    let taskId: UUID // ID of the parent task
    let taskTitle: String
    let taskType: TaskType
    let priority: Priority
    let dueDate: Date
    let subjectName: String
    let subjectCode: String
    let subjectColor: String
    let miniTask: MiniTask
    let priorityScore: Double // 0.0 to 1.0
    let aiReasoning: String
}

// MARK: - Claude Service
class ClaudeService {
    static let shared = ClaudeService()
    
    private init() {}
    
    // MARK: - Main Priority Function
    func prioritizeMiniMissions(
        candidates: [(task: Task, miniTask: MiniTask)],
        completion: @escaping ([PrioritizedMiniMission]) -> Void
    ) {
        // Build context for Claude
        let prompt = buildPrioritizationPrompt(candidates: candidates)
        
        // Call Claude API (using _Concurrency.Task to avoid conflict with Task model)
        _Concurrency.Task {
            do {
                let prioritized = try await callClaudeAPI(prompt: prompt, candidates: candidates)
                DispatchQueue.main.async {
                    completion(prioritized)
                }
            } catch {
                print("Error calling Claude API: \(error)")
                // Fallback to simple prioritization
                let fallback = simplePrioritization(candidates: candidates)
                DispatchQueue.main.async {
                    completion(fallback)
                }
            }
        }
    }
    
    // MARK: - Build Prompt
    private func buildPrioritizationPrompt(candidates: [(task: Task, miniTask: MiniTask)]) -> String {
        let currentDate = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        
        var prompt = """
        Eres un asistente académico experto en gestión del tiempo para estudiantes. Tu tarea es priorizar mini-misiones para HOY.
        
        FECHA ACTUAL: \(formatter.string(from: currentDate))
        
        CRITERIOS DE PRIORIZACIÓN (en orden de importancia):
        1. URGENCIA: Tareas con deadline cercano tienen máxima prioridad
        2. TIPO DE TAREA: Exámenes > Proyectos > Assignments > Quizzes > Homework > Reading
        3. PROGRESO: Tareas con menos mini-misiones completadas necesitan más atención
        4. BALANCE: Distribuir entre diferentes materias cuando sea posible
        
        CANDIDATOS PARA HOY:
        
        """
        
        for (index, candidate) in candidates.enumerated() {
            let task = candidate.task
            let miniTask = candidate.miniTask
            let daysRemaining = task.daysRemaining
            let allMiniTasks = generateMiniTasks(for: task)
            let completedCount = allMiniTasks.filter { $0.isCompleted }.count
            let totalCount = allMiniTasks.count
            
            prompt += """
            
            CANDIDATO #\(index + 1):
            - Mini-misión: "\(miniTask.title)" (Día \(miniTask.dayNumber))
            - Tarea padre: "\(task.title)"
            - Tipo: \(task.taskType.rawValue.uppercased())
            - Materia: \(task.subjectCode) - \(task.subjectName)
            - Prioridad original: \(task.priority.rawValue.uppercased())
            - Días hasta deadline: \(daysRemaining) días
            - Progreso: \(completedCount)/\(totalCount) mini-misiones completadas
            - Debe empezar: \(task.shouldBeStarted ? "SÍ (urgente)" : "NO")
            
            """
        }
        
        prompt += """
        
        INSTRUCCIONES:
        1. Analiza todos los candidatos
        2. Selecciona las 3 mini-misiones MÁS IMPORTANTES para completar HOY
        3. Para cada una, asigna un score de 0.0 a 1.0 (1.0 = máxima prioridad)
        4. Explica brevemente por qué es prioritaria
        
        FORMATO DE RESPUESTA (JSON):
        {
            "priorities": [
                {
                    "candidate_number": 1,
                    "priority_score": 0.95,
                    "reasoning": "Examen en 2 días, alta urgencia"
                },
                {
                    "candidate_number": 3,
                    "priority_score": 0.85,
                    "reasoning": "Proyecto con deadline cercano, progreso bajo"
                },
                {
                    "candidate_number": 2,
                    "priority_score": 0.70,
                    "reasoning": "Assignment importante, balance de materias"
                }
            ]
        }
        
        Responde SOLO con el JSON, sin texto adicional.
        """
        
        return prompt
    }
    
    // MARK: - Call Claude API
    private func callClaudeAPI(
        prompt: String,
        candidates: [(task: Task, miniTask: MiniTask)]
    ) async throws -> [PrioritizedMiniMission] {
        
        // Prepare request
        let request = ClaudeRequest(
            model: ClaudeConfig.model,
            max_tokens: ClaudeConfig.maxTokens,
            messages: [
                ClaudeMessage(role: "user", content: prompt)
            ],
            system: "Eres un experto en priorización de tareas académicas. Siempre respondes en formato JSON válido."
        )
        
        // Create URL request
        guard let url = URL(string: ClaudeConfig.apiURL) else {
            throw NSError(domain: "ClaudeService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(ClaudeConfig.apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        
        let encoder = JSONEncoder()
        urlRequest.httpBody = try encoder.encode(request)
        
        // Make request
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        // Check response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "ClaudeService", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("Claude API Error (\(httpResponse.statusCode)): \(errorMessage)")
            throw NSError(domain: "ClaudeService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])
        }
        
        // Parse response
        let decoder = JSONDecoder()
        let claudeResponse = try decoder.decode(ClaudeResponse.self, from: data)
        
        guard let responseText = claudeResponse.content.first?.text else {
            throw NSError(domain: "ClaudeService", code: -3, userInfo: [NSLocalizedDescriptionKey: "No content in response"])
        }
        
        // Parse JSON response
        let priorities = try parseClaudeResponse(responseText: responseText, candidates: candidates)
        
        return priorities
    }
    
    // MARK: - Parse Claude Response
    private func parseClaudeResponse(
        responseText: String,
        candidates: [(task: Task, miniTask: MiniTask)]
    ) throws -> [PrioritizedMiniMission] {
        
        struct PriorityResponse: Codable {
            let priorities: [PriorityItem]
        }
        
        struct PriorityItem: Codable {
            let candidate_number: Int
            let priority_score: Double
            let reasoning: String
        }
        
        // Extract JSON from response (in case there's extra text)
        let jsonText = extractJSON(from: responseText)
        
        guard let jsonData = jsonText.data(using: .utf8) else {
            throw NSError(domain: "ClaudeService", code: -4, userInfo: [NSLocalizedDescriptionKey: "Cannot convert response to data"])
        }
        
        let decoder = JSONDecoder()
        let priorityResponse = try decoder.decode(PriorityResponse.self, from: jsonData)
        
        // Map to PrioritizedMiniMission
        var result: [PrioritizedMiniMission] = []
        
        for priority in priorityResponse.priorities.prefix(3) {
            let index = priority.candidate_number - 1
            guard index >= 0 && index < candidates.count else { continue }
            
            let candidate = candidates[index]
            result.append(
                PrioritizedMiniMission(
                    id: candidate.miniTask.id,
                    taskId: candidate.task.id,
                    taskTitle: candidate.task.title,
                    taskType: candidate.task.taskType,
                    priority: candidate.task.priority,
                    dueDate: candidate.task.dueDate,
                    subjectName: candidate.task.subjectName,
                    subjectCode: candidate.task.subjectCode,
                    subjectColor: candidate.task.subjectColor,
                    miniTask: candidate.miniTask,
                    priorityScore: priority.priority_score,
                    aiReasoning: priority.reasoning
                )
            )
        }
        
        return result
    }
    
    // MARK: - Extract JSON from text
    private func extractJSON(from text: String) -> String {
        // Find JSON block between { and }
        if let startIndex = text.firstIndex(of: "{"),
           let endIndex = text.lastIndex(of: "}") {
            return String(text[startIndex...endIndex])
        }
        return text
    }
    
    // MARK: - Fallback Simple Prioritization
    private func simplePrioritization(
        candidates: [(task: Task, miniTask: MiniTask)]
    ) -> [PrioritizedMiniMission] {
        
        // Sort by: urgency, task type priority, progress
        let sorted = candidates.sorted { candidate1, candidate2 in
            let task1 = candidate1.task
            let task2 = candidate2.task
            
            // 1. Days remaining (less is more urgent)
            if task1.daysRemaining != task2.daysRemaining {
                return task1.daysRemaining < task2.daysRemaining
            }
            
            // 2. Task type priority
            let type1Priority = taskTypePriority(task1.taskType)
            let type2Priority = taskTypePriority(task2.taskType)
            if type1Priority != type2Priority {
                return type1Priority > type2Priority
            }
            
            // 3. Original priority
            let priority1 = priorityScore(task1.priority)
            let priority2 = priorityScore(task2.priority)
            return priority1 > priority2
        }
        
        // Take top 3
        return sorted.prefix(3).enumerated().map { index, candidate in
            PrioritizedMiniMission(
                id: candidate.miniTask.id,
                taskId: candidate.task.id,
                taskTitle: candidate.task.title,
                taskType: candidate.task.taskType,
                priority: candidate.task.priority,
                dueDate: candidate.task.dueDate,
                subjectName: candidate.task.subjectName,
                subjectCode: candidate.task.subjectCode,
                subjectColor: candidate.task.subjectColor,
                miniTask: candidate.miniTask,
                priorityScore: 1.0 - (Double(index) * 0.15), // 1.0, 0.85, 0.70
                aiReasoning: "Priorizado por urgencia y tipo de tarea"
            )
        }
    }
    
    private func taskTypePriority(_ type: TaskType) -> Int {
        switch type {
        case .exam, .midterm, .final: return 6
        case .project: return 5
        case .assignment: return 4
        case .quiz: return 3
        case .homework: return 2
        case .reading: return 1
        case .other: return 0
        }
    }
    
    private func priorityScore(_ priority: Priority) -> Int {
        switch priority {
        case .critical: return 3
        case .important: return 2
        case .chill: return 1
        }
    }

    // MARK: - Syllabus Parsing Function
    func parseSyllabus(
        text: String,
        subjectCode: String?,
        completion: @escaping (Result<SyllabusParseResponse, Error>) -> Void
    ) {
        let prompt = buildSyllabusParsingPrompt(text: text, subjectCode: subjectCode)

        _Concurrency.Task {
            do {
                let result = try await callClaudeForSyllabusParsing(prompt: prompt)
                DispatchQueue.main.async {
                    completion(.success(result))
                }
            } catch {
                print("Error parsing syllabus: \(error)")
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }

    // MARK: - Build Syllabus Parsing Prompt
    private func buildSyllabusParsingPrompt(text: String, subjectCode: String?) -> String {
        let currentDate = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let currentDateString = formatter.string(from: currentDate)

        let subjectHint = subjectCode != nil ? "\nDetected subject code: \(subjectCode!)" : ""

        return """
        You are a syllabus parser for a student time management app. Extract all academic deadlines from the following syllabus text and return ONLY valid JSON.

        CURRENT DATE: \(currentDateString)
        \(subjectHint)

        EXTRACT:
        - Task name/title (be specific and clear)
        - Task type: Must be one of: exam, midterm, final, assignment, project, quiz, reading, homework
        - Due date in ISO 8601 format (YYYY-MM-DD). If year is not specified, assume current academic year.
        - Weight/percentage if mentioned (e.g., "20%")
        - Any special notes or instructions
        - Subject name (full course name if found in document)
        - Subject code (course code if different from detected)

        RULES:
        - If exact date is unclear or ambiguous, set dueDate to null
        - Classify task types accurately based on keywords
        - For "Week X" references, calculate actual dates if semester start date is mentioned
        - Extract ALL academic deadlines - don't skip any
        - Be specific with task titles (e.g., "Assignment 2" not just "Assignment")
        - Return empty array if no tasks found
        - Priority assignment:
          * exam/midterm/final = CRITICAL
          * assignment/project = IMPORTANT
          * quiz/reading/homework = CHILL

        SYLLABUS TEXT:
        \(text)

        Return JSON in this exact format:
        {
            "subjectName": "Programming Languages",
            "subjectCode": "CSC324",
            "tasks": [
                {
                    "title": "Assignment 1: Functional Programming",
                    "type": "assignment",
                    "dueDate": "2025-10-20",
                    "weight": "15%",
                    "notes": "Submit via Canvas"
                },
                {
                    "title": "Midterm Exam",
                    "type": "midterm",
                    "dueDate": "2025-11-05",
                    "weight": "30%",
                    "notes": "Covers weeks 1-6"
                }
            ]
        }

        Respond ONLY with valid JSON, no other text.
        """
    }

    // MARK: - Call Claude for Syllabus Parsing
    private func callClaudeForSyllabusParsing(prompt: String) async throws -> SyllabusParseResponse {
        print("🔵 [ClaudeService] Starting syllabus parsing...")
        print("🔵 [ClaudeService] API URL: \(ClaudeConfig.apiURL)")
        print("🔵 [ClaudeService] Model: \(ClaudeConfig.model)")
        
        // Prepare request
        let request = ClaudeRequest(
            model: ClaudeConfig.model,
            max_tokens: 4096, // Increased for longer syllabus responses
            messages: [
                ClaudeMessage(role: "user", content: prompt)
            ],
            system: "You are an expert syllabus parser. Always respond with valid JSON only, no additional text."
        )

        // Create URL request
        guard let url = URL(string: ClaudeConfig.apiURL) else {
            print("❌ [ClaudeService] Invalid URL")
            throw NSError(domain: "ClaudeService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(ClaudeConfig.apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        urlRequest.httpBody = try encoder.encode(request)
        
        if let requestBody = urlRequest.httpBody,
           let requestString = String(data: requestBody, encoding: .utf8) {
            print("🔵 [ClaudeService] Request body (first 500 chars):")
            print(String(requestString.prefix(500)))
        }

        // Make request
        print("🔵 [ClaudeService] Sending request to Claude API...")
        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        // Check response
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ [ClaudeService] Invalid HTTP response")
            throw NSError(domain: "ClaudeService", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }

        print("🔵 [ClaudeService] Response status code: \(httpResponse.statusCode)")

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ [ClaudeService] API Error (\(httpResponse.statusCode)):")
            print(errorMessage)
            throw NSError(domain: "ClaudeService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])
        }

        // Parse response
        let decoder = JSONDecoder()
        
        if let responseString = String(data: data, encoding: .utf8) {
            print("🔵 [ClaudeService] Raw response (first 500 chars):")
            print(String(responseString.prefix(500)))
        }
        
        let claudeResponse = try decoder.decode(ClaudeResponse.self, from: data)

        guard let responseText = claudeResponse.content.first?.text else {
            print("❌ [ClaudeService] No content in Claude response")
            throw NSError(domain: "ClaudeService", code: -3, userInfo: [NSLocalizedDescriptionKey: "No content in response"])
        }

        print("🔵 [ClaudeService] Claude response text:")
        print(responseText)

        // Extract and parse JSON
        let jsonText = extractJSON(from: responseText)
        
        print("🔵 [ClaudeService] Extracted JSON:")
        print(jsonText)

        guard let jsonData = jsonText.data(using: .utf8) else {
            print("❌ [ClaudeService] Cannot convert JSON to data")
            throw NSError(domain: "ClaudeService", code: -4, userInfo: [NSLocalizedDescriptionKey: "Cannot convert response to data"])
        }

        let syllabusResponse = try decoder.decode(SyllabusParseResponse.self, from: jsonData)
        
        print("✅ [ClaudeService] Successfully parsed syllabus!")
        print("✅ [ClaudeService] Found \(syllabusResponse.tasks.count) tasks")
        print("✅ [ClaudeService] Subject: \(syllabusResponse.subjectName ?? "Unknown")")

        return syllabusResponse
    }

    // MARK: - Convert Parsed Task to Task Model
    func convertToTask(
        parsedTask: ParsedTask,
        subjectCode: String,
        subjectName: String,
        subjectColor: String
    ) -> Task? {
        // Parse task type
        guard let taskType = parseTaskType(parsedTask.type) else {
            return nil
        }

        // Parse due date
        guard let dueDate = parseDateString(parsedTask.dueDate) else {
            return nil
        }

        // Assign priority based on task type
        let priority = assignPriority(for: taskType)

        // Combine notes with weight if available
        var notes = parsedTask.notes ?? ""
        if let weight = parsedTask.weight {
            notes = notes.isEmpty ? "Weight: \(weight)" : "\(notes)\nWeight: \(weight)"
        }

        return Task(
            title: parsedTask.title,
            taskType: taskType,
            priority: priority,
            dueDate: dueDate,
            subjectName: subjectName,
            subjectCode: subjectCode,
            subjectColor: subjectColor,
            isCompleted: false,
            notes: notes.isEmpty ? nil : notes
        )
    }

    // MARK: - Parse Task Type
    private func parseTaskType(_ typeString: String) -> TaskType? {
        let normalized = typeString.lowercased()

        switch normalized {
        case "exam": return .exam
        case "midterm": return .midterm
        case "final": return .final
        case "assignment": return .assignment
        case "project": return .project
        case "quiz": return .quiz
        case "reading": return .reading
        case "homework": return .homework
        default: return nil
        }
    }

    // MARK: - Parse Date String
    private func parseDateString(_ dateString: String?) -> Date? {
        guard let dateString = dateString else { return nil }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        return formatter.date(from: dateString)
    }

    // MARK: - Assign Priority
    private func assignPriority(for taskType: TaskType) -> Priority {
        switch taskType {
        case .exam, .midterm, .final:
            return .critical
        case .assignment, .project:
            return .important
        case .quiz, .reading, .homework, .other:
            return .chill
        }
    }
}
