# Schedora - iOS APP (previous LazyButSmart)

**iOS Time Manager for Students** - Automatically converts university syllabi into a visual timeline with smart prioritization.

## 📁 Project Structure

```
LazyButSmart/
├── LazyButSmart/                    # Xcode Project Folder
│   ├── LazyButSmart.xcodeproj/     # Xcode project file (OPEN THIS)
│   ├── LazyButSmart/               # Main source code
│   │   ├── LazyButSmartApp.swift   # App entry point
│   │   ├── ContentView.swift       # Main view
│   │   ├── DesignSystem.swift      # Colors, fonts, spacing
│   │   ├── Models/                 # Data models
│   │   │   ├── Task.swift
│   │   │   └── Subject.swift
│   │   ├── Components/             # Reusable UI components
│   │   │   ├── ProgressRing.swift
│   │   │   ├── TaskCard.swift
│   │   │   └── SubjectProgressCard.swift
│   │   ├── Views/                  # Screen views
│   │   │   └── DashboardView.swift
│   │   └── Assets.xcassets/        # Images, colors, icons
│   ├── LazyButSmartTests/          # Unit tests
│   └── LazyButSmartUITests/        # UI tests
│
└── Documentation/                   # Project documentation
    ├── README_XCODE.md             # Setup instructions
    ├── overview.txt                # Project overview & specs
    └── claude.txt                  # AI development prompts
```

## 📱 Current Features
✅ LLM PDF parsing functionality
✅ Dashboard with progress rings  
✅ Task timeline view  
✅ Subject filtering  
✅ Priority system (🔴🟡🟢)  
✅ Dark mode design system  
✅ Mock data for testing  

## 📚 Documentation

All project documentation is in the `Documentation/` folder:
- **README_XCODE.md** - Detailed Xcode setup guide
- **overview.txt** - Complete project specifications

## 🎨 Design System

- **Notebook Background First:**
- **Brand Voice:** Direct, honest, anti-corporate
- **Priority Colors:** Red (Critical), Yellow (Important), Green (Chill)
- **Typography:** SF Pro system fonts

## 🔧 Tech Stack
- **Platform:** iOS 17.0+
- **Language:** Swift
- **Framework:** SwiftUI
- **Architecture:** MVVM (planned)

## 📝 Next Steps
- [ ] Implement Core Data storage
- [ ] Create onboarding flow
