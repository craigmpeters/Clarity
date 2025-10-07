import SwiftUI
import SwiftData

@available(iOS 26.0, *)
struct SuggestionRow: View {
    @Binding var suggestion: SplitTaskSuggestion
    let allCategories: [Category]
    let applyGlobalCategories: Bool
    let globalCategories: [CategoryDTO]
    @State private var showingCategoryPicker = false
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        suggestion.isSelected.toggle()
                    }
                } label: {
                    Image(systemName: suggestion.isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundStyle(suggestion.isSelected ? .blue : .secondary)
                }
                .buttonStyle(.plain)
                
                VStack(alignment: .leading, spacing: 6) {
                    TextField("Task name", text: $suggestion.name)
                        .font(.subheadline)
                        .textFieldStyle(.plain)
                        .disabled(!suggestion.isSelected)
                    
                    HStack(spacing: 12) {
                        // Duration with timer icon
                        HStack(spacing: 4) {
                            Image(systemName: "timer")
                                .font(.caption)
                                .foregroundStyle(.orange)
                            
                            Stepper(value: $suggestion.estimatedMinutes, in: 5...25, step: 5) {
                                Text("\(suggestion.estimatedMinutes) min")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        Divider()
                            .frame(height: 16)
                        
                        // Category button (disabled if global categories are applied)
                        if !applyGlobalCategories {
                            Button(action: { showingCategoryPicker = true }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "tag")
                                        .font(.caption)
                                        .foregroundStyle(.blue)
                                    
                                    if suggestion.selectedCategories.isEmpty {
                                        Text("Add category")
                                            .font(.caption)
                                            .foregroundStyle(.blue)
                                    } else {
                                        Text("\(suggestion.selectedCategories.count)")
                                            .font(.caption)
                                            .foregroundStyle(.blue)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .disabled(!suggestion.isSelected)
                        }
                    }
                    
                    // Show selected categories
                    if !suggestion.selectedCategories.isEmpty || applyGlobalCategories {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(applyGlobalCategories ? globalCategories : suggestion.selectedCategories, id: \.id) { category in
                                    HStack(spacing: 4) {
                                        Circle()
                                            .fill(category.color.SwiftUIColor)
                                            .frame(width: 8, height: 8)
                                        Text(category.name)
                                            .font(.caption2)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(category.color.SwiftUIColor.opacity(0.15))
                                    .cornerRadius(8)
                                }
                            }
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(suggestion.isSelected ? Color.blue.opacity(0.05) : Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(suggestion.isSelected ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .opacity(suggestion.isSelected ? 1.0 : 0.6)
        .sheet(isPresented: $showingCategoryPicker) {
            CategoryPickerSheet(selectedCategories: $suggestion.selectedCategories)
        }
    }
}
