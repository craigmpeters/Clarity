import SwiftUI
import SwiftData

struct CategorySelectionView: View {
    @Binding var selectedCategories: [Category]
    @Query private var allCategories: [Category]
    @State private var showingAddCategory = false
    
    
    
    var body: some View {
        VStack(spacing: 8) {
            // Header row with label and add button
            HStack {
                Text("Categories")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: { showingAddCategory = true }) {
                    Image(systemName: "plus")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(.systemGray4), lineWidth: 0.5)
                    )
            )
            
            // Categories row
            if !allCategories.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(allCategories) { category in
                            CategoryChip(
                                category: category,
                                isSelected: selectedCategories.contains { $0.id == category.id }
                            ) {
                                toggleCategory(category)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                }
            }
        }
        .sheet(isPresented: $showingAddCategory) {
            AddCategoryView()
        }
        .onAppear {
            print("Available categories: \(allCategories.map { $0.id.storeIdentifier ?? "nil" })")
        }
    }

        
    
    private func toggleCategory(_ category: Category) {
        if let index = selectedCategories.firstIndex(where: { $0.id == category.id }) {
            selectedCategories.remove(at: index)
        } else {
            selectedCategories.append(category)
        }
    }
}

struct CategoryChip: View {
    let category: Category
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                // Color indicator circle
                Circle()
                    .fill(category.color.SwiftUIColor)
                    .frame(width: 12, height: 12)
                
                Text(category.name)
                    .font(.caption)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? category.color.SwiftUIColor.opacity(0.15) : Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                isSelected ? category.color.SwiftUIColor : Color(.systemGray4),
                                lineWidth: isSelected ? 2 : 0.5
                            )
                    )
            )
            .foregroundColor(isSelected ? category.color.SwiftUIColor : .primary)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct AddCategoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var selectedColor: Category.CategoryColor = .Red
    
    
    
    var body: some View {
        NavigationView {
            Form {
                Section("Category Details") {
                    TextField("Category Name", text: $name)
                }
                
                Section("Color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 16) {
                        ForEach(Category.CategoryColor.allCases, id: \.self) { color in
                            Button(action: {
                                selectedColor = color
                            }) {
                                VStack(spacing: 4) {
                                    Circle()
                                        .fill(color.SwiftUIColor)
                                        .frame(width: 32, height: 32)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.white, lineWidth: 2)
                                                .opacity(selectedColor == color ? 1 : 0)
                                        )
                                        .overlay(
                                            Circle()
                                                .stroke(Color.primary, lineWidth: 1)
                                                .opacity(selectedColor == color ? 1 : 0)
                                        )
                                    
                                    Text(color.rawValue)
                                        .font(.caption2)
                                        .foregroundColor(selectedColor == color ? color.SwiftUIColor : .secondary)
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("New Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveCategory()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
    
    private func saveCategory() {
        let newCategory = Category(name: name, color: selectedColor)
        print("Created category: \(name), ID before insert: \(newCategory.id)")
        
        modelContext.insert(newCategory)
        print("Category ID after insert: \(newCategory.id)")
        
        do {
            try modelContext.save()
            print("Category ID after save: \(newCategory.id)")
            dismiss()
        } catch {
            print("Failed to save category: \(error)")
        }
    }
}

// Usage in your task creation form:
struct TaskCreationView: View {
    @State private var taskToAdd = ToDoTask(name: "", pomodoro: true, pomodoroTime: 25 * 60)
    @State private var selectedCategories: [Category] = []
    
    var body: some View {
        VStack(spacing: 16) {
            TextField("Task Name", text: $taskToAdd.name)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            CategorySelectionView(selectedCategories: $selectedCategories)
            
            // Your other task creation controls...
            
            Button("Create Task") {
                taskToAdd.categories = selectedCategories
                // Save task logic
            }
            .disabled(taskToAdd.name.isEmpty)
        }
        .padding()
    }
}

//#Preview {
//    do {
//        let config = ModelConfiguration(isStoredInMemoryOnly: true)
//        let container = try ModelContainer(for: Category.self, ToDoTask.self, configurations: config)
//        
//        let workCategory = Category(name: "Work", color: .Blue)
//        let personalCategory = Category(name: "Personal", color: .Green)
//        let urgentCategory = Category(name: "Urgent", color: .Red)
//        
//        container.mainContext.insert(workCategory)
//        container.mainContext.insert(personalCategory)
//        container.mainContext.insert(urgentCategory)
//        
//        return CategorySelectionView(selectedCategories: .constant([workCategory]))
//            .modelContainer(container)
//            .padding()
//    } catch {
//        return Text("Preview Error: \(error.localizedDescription)")
//    }
//}
