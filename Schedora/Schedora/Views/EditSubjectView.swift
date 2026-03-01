//
//  EditSubjectView.swift
//  Schedora
//
//  View for adding or editing a subject
//

import SwiftUI

struct EditSubjectView: View {
    @Environment(\.dismiss) private var dismiss
    
    var subject: Subject?
    let onSave: (String, String, String) -> Void
    let onDelete: (() -> Void)?
    
    @State private var name: String = ""
    @State private var code: String = ""
    @State private var selectedColor: String = "FF6B6B"
    @State private var showDeleteAlert = false
    
    var isEditing: Bool {
        subject != nil
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                NotebookPaperBackground(showMargin: false)
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Name field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Subject Name")
                                .font(.appBodyBold)
                                .foregroundColor(.textPrimary)
                            
                            TextField("e.g., Data Structures", text: $name)
                                .textFieldStyle(CustomTextFieldStyle())
                        }
                        
                        // Code field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Subject Code")
                                .font(.appBodyBold)
                                .foregroundColor(.textPrimary)
                            
                            TextField("e.g., CSC373", text: $code)
                                .textFieldStyle(CustomTextFieldStyle())
                                .textCase(.uppercase)
                        }
                        
                        // Color picker
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Color")
                                .font(.appBodyBold)
                                .foregroundColor(.textPrimary)
                            
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                                ForEach(subjectColorOptions, id: \.self) { color in
                                    Button(action: {
                                        selectedColor = color
                                    }) {
                                        Circle()
                                            .fill(Color(hex: color))
                                            .frame(width: 44, height: 44)
                                            .overlay(
                                                Circle()
                                                    .stroke(selectedColor == color ? Color.textPrimary : Color.clear, lineWidth: 3)
                                            )
                                            .overlay(
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 16, weight: .bold))
                                                    .foregroundColor(.white)
                                                    .opacity(selectedColor == color ? 1 : 0)
                                            )
                                    }
                                }
                            }
                        }
                        
                        // Preview
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Preview")
                                .font(.appBodyBold)
                                .foregroundColor(.textPrimary)
                            
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(Color(hex: selectedColor))
                                    .frame(width: 40, height: 40)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(code.isEmpty ? "CODE" : code.uppercased())
                                        .font(.appBodyBold)
                                        .foregroundColor(Color(hex: selectedColor))
                                    
                                    Text(name.isEmpty ? "Subject Name" : name)
                                        .font(.appCaption)
                                        .foregroundColor(.textSecondary)
                                }
                                
                                Spacer()
                            }
                            .padding()
                            .background(Color.bgSecondary)
                            .cornerRadius(.cornerRadiusMedium)
                        }
                        
                        Spacer(minLength: 40)
                        
                        // Delete button (only for editing, not for ALL)
                        if isEditing && subject?.code != "ALL" {
                            Button(action: {
                                showDeleteAlert = true
                            }) {
                                HStack {
                                    Image(systemName: "trash")
                                    Text("Delete Subject")
                                }
                                .font(.appBodyBold)
                                .foregroundColor(.criticalRed)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.criticalRed.opacity(0.1))
                                .cornerRadius(.cornerRadiusMedium)
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle(isEditing ? "Edit Subject" : "Add Subject")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.textSecondary)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(name, code.uppercased(), selectedColor)
                        dismiss()
                    }
                    .disabled(name.isEmpty || code.isEmpty)
                    .foregroundColor(name.isEmpty || code.isEmpty ? .textSecondary : .accentOrange)
                    .fontWeight(.bold)
                }
            }
            .alert("Delete Subject", isPresented: $showDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    onDelete?()
                    dismiss()
                }
            } message: {
                Text("Are you sure you want to delete this subject? Tasks associated with this subject will not be deleted.")
            }
        }
        .onAppear {
            if let subject = subject {
                name = subject.name
                code = subject.code
                selectedColor = subject.color
            }
        }
    }
}

// Custom text field style
struct CustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(Color.bgSecondary)
            .cornerRadius(.cornerRadiusMedium)
            .overlay(
                RoundedRectangle(cornerRadius: .cornerRadiusMedium)
                    .stroke(Color.textSecondary.opacity(0.2), lineWidth: 1)
            )
    }
}

#Preview {
    EditSubjectView(
        subject: nil,
        onSave: { _, _, _ in },
        onDelete: nil
    )
}
