# Schedora — Documentation

> Student time management app that converts university syllabi into a visual timeline with AI-powered task extraction and prioritization.

---

## 1. Overview

**Schedora** (formerly LazyButSmart) is an iOS app that helps students organize their academic deadlines. Upload a PDF syllabus → AI extracts every deadline → tasks appear on an interactive Gantt-style timeline → daily mini-missions tell you what to work on today.

**Brand voice:** Direct, honest, anti-corporate. "Lazy but smart."

**Tech stack:**
- iOS 17+ / Swift / SwiftUI
- MVVM-ish architecture with ObservableObject managers
- PDFKit + Vision (OCR fallback) for PDF text extraction
- Google Gemini API (gemini-2.5-flash) for AI parsing & prioritization
- No third-party dependencies beyond the Gemini API call

---

## 2. Project Structure

```
LazyButSmart/
├── LazyButSmartApp.swift          — App entry point
├── ContentView.swift              — Root view
├── DesignSystem.swift             — Colors, fonts, reusable styles
├── Models/
│   ├── Subject.swift              — Subject model (name, code, color)
│   ├── Task.swift                 — Task model (title, type, priority, dates)
│   └── MockData.swift             — Sample data for development
├── Components/
│   ├── PriorityBadge.swift        — Priority indicator (CRITICAL/IMPORTANT/CHILL)
│   ├── ProgressRing.swift         — Circular progress indicator
│   ├── SubjectProgressCard.swift  — Subject card with stats
│   └── TaskCard.swift             — Task card component
├── Views/
│   ├── MainTabView.swift          — Bottom tab bar (Timeline / + / Tasks)
│   ├── DashboardView.swift        — Main dashboard with subjects + timeline
│   ├── TimelineView.swift         — Gantt-style horizontal timeline
│   ├── TaskListView.swift         — Vertical task list with filters
│   ├── TaskDetailView.swift       — Task detail with mini-missions
│   ├── CalendarView.swift         — Monthly calendar view
│   ├── AddTaskView.swift          — Manual task creation
│   ├── EditSubjectView.swift      — Subject CRUD
│   └── UploadPDFView.swift        — PDF upload + AI parsing flow
├── Services/
│   ├── GeminiService.swift        — Google Gemini API (parsing + prioritization)
│   ├── ClaudeService.swift        — Legacy Claude API (disabled, holds shared models)
│   ├── PDFProcessingService.swift — PDF text extraction + OCR
│   ├── TaskManager.swift          — Centralized task state
│   ├── SubjectManager.swift       — Subject CRUD + stats
│   └── MiniTaskManager.swift      — Daily mini-task generation
```

---

## 3. Core Features

### 3.1 PDF Syllabus Parsing
**Flow:** User taps "+" → selects PDF → `PDFProcessingService` extracts text (PDFKit first, Vision OCR fallback) → `GeminiService` sends text to Gemini API with structured prompt → AI returns JSON with tasks → app creates Task objects + Subject automatically.

**UI states:** Idle → Processing (with progress) → Success (shows task count) → Error (with retry)

### 3.2 Interactive Timeline (Notion-style Gantt)
- Horizontal scroll, one column per day (`dayWidth = 60`)
- Tasks grouped by subject in VStack rows with bin-packing sub-rows for overlaps
- **Drag handles:** Left edge = adjust start date, right edge = adjust due date (20px real touch targets with `highPriorityGesture`)
- Date labels on all columns, "HOY" (today) marker, semester end marker
- Subject order: nearest upcoming deadline first, overdue-only subjects last

### 3.3 Task Duration System
Each `TaskType` has default preparation days:
| Type | Days | Priority |
|------|------|----------|
| Final | 14 | Critical |
| Midterm | 10 | Critical |
| Exam | 10 | Critical |
| Project | 10 | Important |
| Assignment | 7 | Important |
| Quiz | 3 | Chill |
| Homework | 3 | Chill |
| Reading | 2 | Chill |

Duration is **inclusive**: `durationDays = (dueDate - startDate).days + 1`

### 3.4 Task List + Filters
- Temporal filters: HOY / ESTA SEMANA / ESTE MES / TODO
- Subject filter pills
- Tasks grouped by subject with completion toggles

### 3.5 To Do Today (Mini-Missions)
- AI selects top 3 mini-missions for today across all active tasks
- Based on urgency, task type importance, and progress
- Falls back to local prioritization if API fails
- Title format: "Avance de (task name)"
- Shows only when "HOY" filter is active

### 3.6 Task Detail View
- AI-generated mini-missions (subtasks) per task type
- Each task type has template subtasks (exams = 10 steps, quizzes = 3, etc.)
- Progress bar, timeline indicator (start → due), checkboxes
- Duration picker with inclusive day counting

---

## 4. AI Integration (Gemini)

**Service:** `GeminiService.swift`
**Model:** `gemini-2.5-flash`
**Endpoint:** `generativelanguage.googleapis.com/v1beta/models/{model}:generateContent`

### Syllabus Parsing
- Prompt asks for JSON with: `subjectName`, `subjectCode`, `tasks[]` (title, type, dueDate, weight, notes)
- Response parsed via `JSONSerialization` (not Codable) for maximum tolerance of type mismatches
- `responseMimeType: "application/json"` for cleaner output

### Task Prioritization
- Sends candidate mini-tasks with due dates, types, days remaining
- Returns top 3 ranked with scores and reasoning
- Fallback: local sort by urgency → type importance → priority

### Shared Models (in ClaudeService.swift)
```swift
struct ParsedTask: Codable {
    let title: String
    let type: String        // exam/midterm/final/assignment/project/quiz/reading/homework
    let dueDate: String?    // YYYY-MM-DD
    let weight: String?
    let notes: String?
}

struct SyllabusParseResponse: Codable {
    let tasks: [ParsedTask]
    let subjectName: String?
    let subjectCode: String?
}
```

---

## 5. Design System

### Colors
| Token | Use |
|-------|-----|
| `.bgPrimary` | Main background (cream/paper) |
| `.bgSecondary` | Card backgrounds |
| `.textPrimary` | Main text (dark brown) |
| `.textSecondary` | Muted text |
| `.accentOrange` | Primary buttons/accents |
| `.criticalRed` | Critical priority |
| `.importantYellow` | Important priority |
| `.chillGreen` | Chill priority |

### Typography
- `.appTitle` — Bold headers
- `.appSubtitle` — Section headers
- `.appBody` — Body text
- `.appCaption` — Small labels
- `.appButton` — Button text

### Priority System
- **CRITICAL** (red) — Exams, midterms, finals
- **IMPORTANT** (yellow) — Assignments, projects
- **CHILL** (green) — Quizzes, homework, reading

---

## 6. Data Flow

```
PDF File
  ↓
PDFProcessingService (PDFKit → text, or Vision OCR fallback)
  ↓
GeminiService.parseSyllabus() → Gemini API → JSON
  ↓
manualParseSyllabus() → [ParsedTask] → [Task]
  ↓
TaskManager.addTasks() + SubjectManager.addSubject()
  ↓
Views update via @Published
```

---

## 7. Setup & Running

1. Open `LazyButSmart.xcodeproj` in Xcode 16+
2. Target: iOS 17.0+, iPhone
3. Gemini API key configured in `GeminiService.swift` line 12
4. Build & Run (⌘R)
5. Tap "+" on dashboard → select a PDF syllabus → tasks auto-created

**Frameworks** (auto-linked): SwiftUI, PDFKit, Vision, Foundation

---

## 8. Known Limitations & Future Work

- **Storage:** Currently uses in-memory mock data. Future: Core Data / SwiftData persistence
- **OCR:** Vision OCR works but accuracy varies with scan quality
- **API:** Gemini free tier has rate limits; ~$0.01-0.05 per parse on paid tier
- **Dates:** AI may struggle with "Week X" references if no semester start date in syllabus
- **Onboarding:** No onboarding flow yet
- **Dark mode:** Partially supported via design system tokens
