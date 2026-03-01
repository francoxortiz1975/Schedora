//
//  DesignSystem.swift
//  Schedora
//
//  School Notebook Theme - Bright & Scholarly
//

import SwiftUI

// MARK: - Color System
extension Color {
    // Background Colors - Warm notebook paper
    static let bgPrimary = Color(hex: "FDF8F3")      // Cream/off-white notebook
    static let bgSecondary = Color(hex: "F5EDE4")    // Slightly darker cream
    static let bgTertiary = Color(hex: "F0E6DA")     // Darker beige for section cards
    
    // Notebook line color
    static let notebookLine = Color(hex: "D4C4B5")   // Soft brown lines
    static let notebookMargin = Color(hex: "E8B4B4") // Pink margin line
    
    // Text Colors - Dark for readability
    static let textPrimary = Color(hex: "2D2D2D")    // Dark charcoal
    static let textSecondary = Color(hex: "6B6B6B")  // Medium gray
    static let textTertiary = Color(hex: "9B9B9B")   // Light gray
    
    // Accent Colors - Brown (Schedora brand)
    static let accentOrange = Color(hex: "6B5B4D")   // Warm brown
    static let accentOrangeLight = Color(hex: "8B7B6D") // Lighter brown
    static let accentYellow = Color(hex: "6B5B4D")   // Keep for compatibility (now brown)
    
    // Priority Colors (Softer for light theme)
    static let criticalRed = Color(hex: "E74C3C")    // Softer red
    static let importantYellow = Color(hex: "F39C12") // Amber
    static let chillGreen = Color(hex: "27AE60")     // Forest green
    
    // Subject Colors (Marker/highlighter colors - work well on cream)
    static let subject1 = Color(hex: "E74C3C") // Red marker
    static let subject2 = Color(hex: "3498DB") // Blue marker
    static let subject3 = Color(hex: "9B59B6") // Purple marker
    static let subject4 = Color(hex: "27AE60") // Green marker
    static let subject5 = Color(hex: "E67E22") // Orange marker
    static let subject6 = Color(hex: "1ABC9C") // Teal marker
    static let subject7 = Color(hex: "F1C40F") // Yellow highlighter
    static let subject8 = Color(hex: "E91E63") // Pink marker
    
    // Helper initializer for hex colors
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Typography System (Elegant serif fonts - Legora style)
extension Font {
    // Display Fonts - Using Baskerville for elegant scholarly feel
    static let appTitle = Font.custom("Baskerville-Bold", size: 28)
    static let appHeadline = Font.custom("Baskerville-SemiBold", size: 20)
    
    // Body Fonts - Clean and readable
    static let appBody = Font.system(size: 16, weight: .regular, design: .default)
    static let appBodyBold = Font.system(size: 16, weight: .semibold, design: .default)
    
    // Small Fonts
    static let appCaption = Font.system(size: 12, weight: .regular, design: .default)
    static let appCaptionBold = Font.system(size: 12, weight: .semibold, design: .default)
    
    // Button Font - Clean and readable
    static let appButton = Font.system(size: 16, weight: .semibold, design: .default)
    
    // Elegant accent font for special text
    static let appHandwritten = Font.custom("Baskerville-Italic", size: 16)
}

// MARK: - Spacing System
extension CGFloat {
    static let spacing4: CGFloat = 4
    static let spacing8: CGFloat = 8
    static let spacing12: CGFloat = 12
    static let spacing16: CGFloat = 16
    static let spacing24: CGFloat = 24
    static let spacing32: CGFloat = 32
    static let spacing48: CGFloat = 48
}

// MARK: - Corner Radius
extension CGFloat {
    static let cornerRadiusSmall: CGFloat = 8
    static let cornerRadiusMedium: CGFloat = 12
    static let cornerRadiusLarge: CGFloat = 16
}

// MARK: - Button Styles (Claude-inspired simple orange buttons)
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.appButton)
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.accentOrange)
            )
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.appButton)
            .foregroundColor(.accentOrange)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.accentOrange, lineWidth: 1.5)
            )
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.appButton)
            .foregroundColor(.accentOrange)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .opacity(configuration.isPressed ? 0.6 : 1.0)
    }
}

// Button style extensions for easy usage
extension View {
    func primaryButtonStyle() -> some View {
        self.buttonStyle(PrimaryButtonStyle())
    }
    
    func secondaryButtonStyle() -> some View {
        self.buttonStyle(SecondaryButtonStyle())
    }
    
    func ghostButtonStyle() -> some View {
        self.buttonStyle(GhostButtonStyle())
    }
}

// MARK: - Notebook Paper Background
struct NotebookPaperBackground: View {
    let lineSpacing: CGFloat = 28
    let marginOffset: CGFloat = 40
    let showMargin: Bool
    
    init(showMargin: Bool = true) {
        self.showMargin = showMargin
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Base cream color
                Color.bgPrimary
                
                // Horizontal lines
                Path { path in
                    var y: CGFloat = lineSpacing + 80 // Start below header area
                    while y < geometry.size.height {
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                        y += lineSpacing
                    }
                }
                .stroke(Color.notebookLine.opacity(0.5), lineWidth: 1)
                
                // Left margin line (pink/red)
                if showMargin {
                    Path { path in
                        path.move(to: CGPoint(x: marginOffset, y: 0))
                        path.addLine(to: CGPoint(x: marginOffset, y: geometry.size.height))
                    }
                    .stroke(Color.notebookMargin.opacity(0.6), lineWidth: 1.5)
                }
                
                // Hole punches on the left
                VStack(spacing: 0) {
                    Spacer()
                        .frame(height: 60)
                    ForEach(0..<5, id: \.self) { _ in
                        Circle()
                            .fill(Color.bgPrimary)
                            .frame(width: 12, height: 12)
                            .overlay(
                                Circle()
                                    .stroke(Color.notebookLine.opacity(0.4), lineWidth: 1)
                            )
                        Spacer()
                            .frame(height: geometry.size.height / 6)
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 8)
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Section Card Modifier (White background for sections)
struct SectionCardStyle: ViewModifier {
    var padding: CGFloat = 16
    
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Color.bgTertiary)
            .cornerRadius(.cornerRadiusMedium)
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
}

extension View {
    func sectionCard(padding: CGFloat = 16) -> some View {
        self.modifier(SectionCardStyle(padding: padding))
    }
}
