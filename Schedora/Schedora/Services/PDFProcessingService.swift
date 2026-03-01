//
//  PDFProcessingService.swift
//  Schedora
//
//  Service for extracting text from PDF syllabi
//

import Foundation
import PDFKit
import Vision

// MARK: - Processed Syllabus Result
struct ProcessedSyllabus {
    let extractedText: String
    let fileName: String
    let detectedSubjectCode: String?
    let detectedSubjectName: String?
}

// MARK: - PDF Processing Service
class PDFProcessingService {
    static let shared = PDFProcessingService()

    private init() {}

    // MARK: - Progress Callback
    typealias ProgressCallback = (Double, String) -> Void

    // MARK: - Main Processing Function
    func processPDF(
        data: Data,
        fileName: String,
        progress: ProgressCallback?
    ) async throws -> ProcessedSyllabus {

        progress?(0.0, "Opening PDF...")

        // Extract text from PDF
        guard let extractedText = extractText(from: data) else {
            // Try OCR fallback
            progress?(0.33, "PDF appears scanned, trying OCR...")
            let ocrText = try await performOCR(on: data)
            progress?(0.66, "Analyzing content...")
            return await analyzeExtractedText(ocrText, fileName: fileName, progress: progress)
        }

        progress?(0.5, "Analyzing content...")
        return await analyzeExtractedText(extractedText, fileName: fileName, progress: progress)
    }

    // MARK: - Extract Text from PDF
    private func extractText(from data: Data) -> String? {
        guard let pdfDocument = PDFDocument(data: data) else {
            return nil
        }

        var fullText = ""

        // Extract text from all pages
        for pageIndex in 0..<pdfDocument.pageCount {
            guard let page = pdfDocument.page(at: pageIndex) else { continue }
            guard let pageText = page.string else { continue }
            fullText += pageText + "\n\n"
        }

        // Clean the text
        let cleaned = cleanExtractedText(fullText)

        return cleaned.isEmpty ? nil : cleaned
    }

    // MARK: - Clean Extracted Text
    private func cleanExtractedText(_ text: String) -> String {
        var cleaned = text

        // Remove excessive whitespace
        cleaned = cleaned.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)

        // Remove page numbers (standalone numbers)
        cleaned = cleaned.replacingOccurrences(of: "\\n\\d+\\n", with: "\n", options: .regularExpression)

        // Normalize line breaks
        cleaned = cleaned.replacingOccurrences(of: "\\n{3,}", with: "\n\n", options: .regularExpression)

        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - OCR Fallback (for scanned PDFs)
    private func performOCR(on data: Data) async throws -> String {
        guard let pdfDocument = PDFDocument(data: data) else {
            throw NSError(domain: "PDFProcessingService", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "Cannot open PDF"])
        }

        var allText = ""

        // Process each page
        for pageIndex in 0..<min(pdfDocument.pageCount, 10) { // Limit to 10 pages for performance
            guard let page = pdfDocument.page(at: pageIndex) else {
                continue
            }
            
            let image = page.thumbnail(of: CGSize(width: 1000, height: 1000), for: .mediaBox)

            // Convert to CGImage
            guard let cgImage = image.cgImage else { continue }

            // Perform OCR
            let pageText = try await recognizeText(in: cgImage)
            allText += pageText + "\n\n"
        }

        return cleanExtractedText(allText)
    }

    // MARK: - Vision Text Recognition
    private func recognizeText(in cgImage: CGImage) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: "")
                    return
                }

                let recognizedText = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }.joined(separator: "\n")

                continuation.resume(returning: recognizedText)
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    // MARK: - Analyze Extracted Text
    private func analyzeExtractedText(
        _ text: String,
        fileName: String,
        progress: ProgressCallback?
    ) async -> ProcessedSyllabus {

        // Detect subject code from filename or text
        let subjectCode = detectSubjectCode(from: text, fileName: fileName)
        let subjectName = detectSubjectName(from: text, subjectCode: subjectCode)

        progress?(1.0, "Ready to parse!")

        return ProcessedSyllabus(
            extractedText: text,
            fileName: fileName,
            detectedSubjectCode: subjectCode,
            detectedSubjectName: subjectName
        )
    }

    // MARK: - Detect Subject Code
    private func detectSubjectCode(from text: String, fileName: String) -> String? {
        // Try filename first
        if let code = extractCourseCode(from: fileName) {
            return code
        }

        // Try first 500 characters of text
        let searchText = String(text.prefix(500))
        return extractCourseCode(from: searchText)
    }

    // MARK: - Extract Course Code with Regex
    private func extractCourseCode(from text: String) -> String? {
        // Pattern: 3-4 letters followed by optional space and 3-4 digits
        // Examples: CSC324, CSC 324, MATH157, PHYS 101
        let pattern = "\\b([A-Z]{3,4})\\s?(\\d{3,4})\\b"

        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return nil
        }

        let nsString = text as NSString
        let results = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))

        guard let match = results.first else {
            return nil
        }

        let letters = nsString.substring(with: match.range(at: 1))
        let numbers = nsString.substring(with: match.range(at: 2))

        return "\(letters)\(numbers)" // Combine without space
    }

    // MARK: - Detect Subject Name
    private func detectSubjectName(from text: String, subjectCode: String?) -> String? {
        guard let code = subjectCode else { return nil }

        // Look for course name near the course code
        // Pattern: CSC324: Course Name or CSC 324 - Course Name
        let patterns = [
            "\(code)[:\\-]\\s*([A-Za-z\\s]+)",
            "\(code)\\s+([A-Z][a-z]+(?:\\s+[A-Z][a-z]+)*)"
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
                continue
            }

            let searchText = String(text.prefix(1000))
            let nsString = searchText as NSString
            let results = regex.matches(in: searchText, options: [], range: NSRange(location: 0, length: nsString.length))

            if let match = results.first, match.numberOfRanges > 1 {
                let courseName = nsString.substring(with: match.range(at: 1))
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                // Clean up common artifacts
                let cleaned = courseName
                    .replacingOccurrences(of: "\\s{2,}", with: " ", options: .regularExpression)
                    .trimmingCharacters(in: CharacterSet.punctuationCharacters)

                if cleaned.count > 3 && cleaned.count < 50 {
                    return cleaned
                }
            }
        }

        return nil
    }
}
