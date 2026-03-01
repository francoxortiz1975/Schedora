//
//  GeminiService.swift
//  Schedora
//
//  Service to integrate with Google Gemini API for intelligent task prioritization & syllabus parsing
//

import Foundation

// MARK: - Gemini API Configuration
struct GeminiConfig {
    // ⚠️ Set your API key in environment variable or replace at build time
    static let apiKey = ProcessInfo.processInfo.environment["GEMINI_API_KEY"] ?? ""
    static let model = "gemini-2.5-flash"
    static let maxOutputTokens = 8192
    
    static var apiURL: String {
        "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)"
    }
}

// MARK: - Gemini API Request Models
struct GeminiRequest: Codable {
    let contents: [GeminiContent]
    let systemInstruction: GeminiContent?
    let generationConfig: GeminiGenerationConfig?
}

struct GeminiContent: Codable {
    let role: String?
    let parts: [GeminiPart]
}

struct GeminiPart: Codable {
    let text: String?
    let thought: Bool?
    
    enum CodingKeys: String, CodingKey {
        case text, thought
    }
    
    init(text: String) {
        self.text = text
        self.thought = nil
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.text = try container.decodeIfPresent(String.self, forKey: .text)
        self.thought = try container.decodeIfPresent(Bool.self, forKey: .thought)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(text, forKey: .text)
        // Don't encode thought — only used for decoding response
    }
}

struct GeminiGenerationConfig: Codable {
    let maxOutputTokens: Int?
    let temperature: Double?
    let responseMimeType: String?
}

// MARK: - Gemini API Response Models
struct GeminiResponse: Codable {
    let candidates: [GeminiCandidate]?
    let error: GeminiError?
}

struct GeminiCandidate: Codable {
    let content: GeminiContent?
    let finishReason: String?
    
    enum CodingKeys: String, CodingKey {
        case content, finishReason
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.content = try container.decodeIfPresent(GeminiContent.self, forKey: .content)
        self.finishReason = try container.decodeIfPresent(String.self, forKey: .finishReason)
    }
}

struct GeminiError: Codable {
    let code: Int?
    let message: String?
    let status: String?
}

// MARK: - Gemini Service
class GeminiService {
    static let shared = GeminiService()
    private init() {}

    // MARK: - Prioritize Mini Missions (uses simple fallback by default, Gemini for AI)
    func prioritizeMiniMissions(
        candidates: [(task: Task, miniTask: MiniTask)],
        completion: @escaping ([PrioritizedMiniMission]) -> Void
    ) {
        guard !candidates.isEmpty else {
            completion([])
            return
        }

        let prompt = buildPrioritizationPrompt(candidates: candidates)

        _Concurrency.Task {
            do {
                let responseText = try await callGeminiAPI(
                    prompt: prompt,
                    systemInstruction: "Eres un experto en priorización de tareas académicas. Siempre respondes en formato JSON válido.",
                    maxTokens: 2048
                )

                let priorities = try self.parsePrioritizationResponse(
                    responseText: responseText,
                    candidates: candidates
                )
                DispatchQueue.main.async {
                    completion(priorities)
                }
            } catch {
                print("⚠️ [GeminiService] AI prioritization failed: \(error). Using fallback.")
                let fallback = self.simplePrioritization(candidates: candidates)
                DispatchQueue.main.async {
                    completion(fallback)
                }
            }
        }
    }

    // MARK: - Build Prioritization Prompt
    private func buildPrioritizationPrompt(candidates: [(task: Task, miniTask: MiniTask)]) -> String {
        var prompt = """
        Prioritize these academic mini-tasks for today. Consider:
        1. Due date urgency (closer = higher priority)
        2. Task type importance (exams > projects > assignments > quizzes > homework > reading)
        3. Task weight/impact
        4. Current progress

        CANDIDATES:
        """

        for (index, candidate) in candidates.enumerated() {
            let task = candidate.task
            let miniTask = candidate.miniTask
            prompt += """

            \(index + 1). Task: \(task.title)
               Type: \(task.taskType.rawValue)
               Priority: \(task.priority.rawValue)
               Due: \(task.dueDate.formatted(date: .abbreviated, time: .omitted))
               Days remaining: \(task.daysRemaining)
               Subject: \(task.subjectName)
               Mini-task: \(miniTask.title)
            """
        }

        prompt += """

        Return JSON with top 3 prioritized tasks:
        {
            "priorities": [
                {
                    "candidate_number": 1,
                    "priority_score": 0.95,
                    "reasoning": "Brief reason in Spanish"
                }
            ]
        }

        Respond ONLY with valid JSON.
        """

        return prompt
    }

    // MARK: - Core Gemini API Call
    private func callGeminiAPI(
        prompt: String,
        systemInstruction: String?,
        maxTokens: Int = GeminiConfig.maxOutputTokens
    ) async throws -> String {
        print("🟢 [GeminiService] Starting API call...")
        print("🟢 [GeminiService] Model: \(GeminiConfig.model)")

        // Build request body
        var systemContent: GeminiContent? = nil
        if let sys = systemInstruction {
            systemContent = GeminiContent(role: nil, parts: [GeminiPart(text: sys)])
        }

        let request = GeminiRequest(
            contents: [
                GeminiContent(role: "user", parts: [GeminiPart(text: prompt)])
            ],
            systemInstruction: systemContent,
            generationConfig: GeminiGenerationConfig(
                maxOutputTokens: maxTokens,
                temperature: 0.2,
                responseMimeType: "application/json"
            )
        )

        // Create URL request
        guard let url = URL(string: GeminiConfig.apiURL) else {
            print("❌ [GeminiService] Invalid URL")
            throw NSError(domain: "GeminiService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = 60

        let encoder = JSONEncoder()
        urlRequest.httpBody = try encoder.encode(request)

        if let requestBody = urlRequest.httpBody,
           let requestString = String(data: requestBody, encoding: .utf8) {
            print("🟢 [GeminiService] Request body (first 500 chars):")
            print(String(requestString.prefix(500)))
        }

        // Make request
        print("🟢 [GeminiService] Sending request to Gemini API...")
        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        // Check response
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ [GeminiService] Invalid HTTP response")
            throw NSError(domain: "GeminiService", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }

        print("🟢 [GeminiService] Response status code: \(httpResponse.statusCode)")

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ [GeminiService] API Error (\(httpResponse.statusCode)):")
            print(errorMessage)
            throw NSError(domain: "GeminiService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])
        }

        // Parse response
        if let responseString = String(data: data, encoding: .utf8) {
            print("🟢 [GeminiService] Raw response (first 500 chars):")
            print(String(responseString.prefix(500)))
        }

        let decoder = JSONDecoder()
        let geminiResponse = try decoder.decode(GeminiResponse.self, from: data)

        // Check for API-level errors
        if let error = geminiResponse.error {
            let msg = error.message ?? "Unknown Gemini error"
            print("❌ [GeminiService] Gemini error: \(msg)")
            throw NSError(domain: "GeminiService", code: error.code ?? -5, userInfo: [NSLocalizedDescriptionKey: msg])
        }

        guard let candidate = geminiResponse.candidates?.first,
              let content = candidate.content else {
            print("❌ [GeminiService] No content in Gemini response")
            throw NSError(domain: "GeminiService", code: -3, userInfo: [NSLocalizedDescriptionKey: "No content in response"])
        }

        // Find the first non-thought part with text
        let textParts = content.parts.filter { $0.thought != true && $0.text != nil }
        guard let text = textParts.first?.text ?? content.parts.compactMap({ $0.text }).last else {
            print("❌ [GeminiService] No text in Gemini response parts")
            throw NSError(domain: "GeminiService", code: -3, userInfo: [NSLocalizedDescriptionKey: "No text content in response"])
        }

        print("🟢 [GeminiService] Response text (first 500):")
        print(String(text.prefix(500)))

        return text
    }

    // MARK: - Parse Prioritization Response
    private func parsePrioritizationResponse(
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

        let jsonText = extractJSON(from: responseText)
        guard let jsonData = jsonText.data(using: .utf8) else {
            throw NSError(domain: "GeminiService", code: -4, userInfo: [NSLocalizedDescriptionKey: "Cannot convert response to data"])
        }

        let decoder = JSONDecoder()
        let priorityResponse = try decoder.decode(PriorityResponse.self, from: jsonData)

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
        if let startIndex = text.firstIndex(of: "{"),
           let endIndex = text.lastIndex(of: "}") {
            return String(text[startIndex...endIndex])
        }
        return text
    }

    // MARK: - Sanitize JSON from Gemini
    // Converts numeric "weight" values to strings and handles null properly
    private func sanitizeJSON(_ json: String) -> String {
        guard let data = json.data(using: .utf8),
              var obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return json
        }
        
        // Sanitize tasks array
        if var tasks = obj["tasks"] as? [[String: Any]] {
            for i in tasks.indices {
                // Fix weight: convert number to string
                if let weight = tasks[i]["weight"] {
                    if let num = weight as? NSNumber {
                        tasks[i]["weight"] = "\(num)%"
                    }
                    // If it's already a string, leave it
                }
                // Fix notes: ensure it's a string or null
                if let notes = tasks[i]["notes"] {
                    if !(notes is String) && !(notes is NSNull) {
                        tasks[i]["notes"] = "\(notes)"
                    }
                }
            }
            obj["tasks"] = tasks
        }
        
        guard let sanitizedData = try? JSONSerialization.data(withJSONObject: obj),
              let result = String(data: sanitizedData, encoding: .utf8) else {
            return json
        }
        return result
    }

    // MARK: - Fallback Simple Prioritization
    private func simplePrioritization(
        candidates: [(task: Task, miniTask: MiniTask)]
    ) -> [PrioritizedMiniMission] {
        let sorted = candidates.sorted { c1, c2 in
            let t1 = c1.task, t2 = c2.task
            if t1.daysRemaining != t2.daysRemaining {
                return t1.daysRemaining < t2.daysRemaining
            }
            let tp1 = taskTypePriority(t1.taskType)
            let tp2 = taskTypePriority(t2.taskType)
            if tp1 != tp2 { return tp1 > tp2 }
            return priorityScore(t1.priority) > priorityScore(t2.priority)
        }

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
                priorityScore: 1.0 - (Double(index) * 0.15),
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
                let responseText = try await callGeminiAPI(
                    prompt: prompt,
                    systemInstruction: "You are an expert syllabus parser. Always respond with valid JSON only, no additional text.",
                    maxTokens: 8192
                )

                let jsonText = self.extractJSON(from: responseText)
                print("🟢 [GeminiService] Extracted JSON (full):")
                print(jsonText)

                // Use manual JSON parsing — much more tolerant than Codable
                let syllabusResponse = try self.manualParseSyllabus(jsonText: jsonText)

                print("✅ [GeminiService] Successfully parsed syllabus!")
                print("✅ [GeminiService] Found \(syllabusResponse.tasks.count) tasks")
                print("✅ [GeminiService] Subject: \(syllabusResponse.subjectName ?? "Unknown")")
                DispatchQueue.main.async {
                    completion(.success(syllabusResponse))
                }
            } catch {
                print("❌ [GeminiService] Error parsing syllabus: \(error)")
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }

    // MARK: - Manual JSON Parsing (tolerant of type mismatches)
    private func manualParseSyllabus(jsonText: String) throws -> SyllabusParseResponse {
        guard let data = jsonText.data(using: .utf8),
              let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "GeminiService", code: -4, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON structure"])
        }

        // Extract subject info (accept any string key variation)
        let subjectName = (root["subjectName"] as? String) ?? (root["subject_name"] as? String)
        let subjectCode = (root["subjectCode"] as? String) ?? (root["subject_code"] as? String)

        // Extract tasks array
        guard let tasksArray = root["tasks"] as? [[String: Any]] else {
            throw NSError(domain: "GeminiService", code: -4, userInfo: [NSLocalizedDescriptionKey: "No tasks array in response"])
        }

        var parsedTasks: [ParsedTask] = []
        for taskDict in tasksArray {
            let title = (taskDict["title"] as? String) ?? "Untitled"
            let type = (taskDict["type"] as? String) ?? "other"

            // dueDate: accept "dueDate" or "due_date"
            let dueDate = (taskDict["dueDate"] as? String) ?? (taskDict["due_date"] as? String)

            // weight: could be String, Int, Double, or null
            var weight: String? = nil
            if let w = taskDict["weight"] as? String {
                weight = w
            } else if let w = taskDict["weight"] as? NSNumber {
                weight = "\(w)%"
            }

            // notes: could be String or anything else
            var notes: String? = nil
            if let n = taskDict["notes"] as? String {
                notes = n
            }

            let parsed = ParsedTask(title: title, type: type, dueDate: dueDate, weight: weight, notes: notes)
            parsedTasks.append(parsed)
        }

        return SyllabusParseResponse(tasks: parsedTasks, subjectName: subjectName, subjectCode: subjectCode)
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

    // MARK: - Convert Parsed Task to Task Model
    func convertToTask(
        parsedTask: ParsedTask,
        subjectCode: String,
        subjectName: String,
        subjectColor: String
    ) -> Task? {
        guard let taskType = parseTaskType(parsedTask.type) else {
            return nil
        }
        guard let dueDate = parseDateString(parsedTask.dueDate) else {
            return nil
        }
        let priority = assignPriority(for: taskType)

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
        switch typeString.lowercased() {
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
