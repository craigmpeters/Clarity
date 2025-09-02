import SwiftData
import SwiftUI

struct CategorySelectionView: View {
    @Binding var selectedCategories: [Category]
    @Query private var allCategories: [Category]
    @State private var showingAddCategory = false
    
    var body: some View {
        HStack {
            Image(systemName: "tag")
                .foregroundColor(.blue)
            Text("Categories")
                
            Spacer()
                
            Button(action: { showingAddCategory = true }) {
                Image(systemName: "plus")
                    .font(.subheadline)
                    .foregroundColor(.blue)
            }
        }
        .sheet(isPresented: $showingAddCategory) {
            AddCategoryView(onCategoryCreated: { newCategory in
                    selectedCategories.append(newCategory)
                })
        }
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
            HStack(spacing: 6) {
                Circle()
                    .fill(category.color.SwiftUIColor)
                    .frame(width: 10, height: 10)
                
                Text(category.name)
                    .font(.caption)
                    .lineLimit(1)
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption2)
                        .fontWeight(.bold)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? category.color.SwiftUIColor.opacity(0.15) : Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                isSelected ? category.color.SwiftUIColor : Color(.systemGray4),
                                lineWidth: isSelected ? 1.5 : 0.5
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
    @State private var weeklyTarget: Int = 0
    
    // Callback to notify parent when category is created
    var onCategoryCreated: ((Category) -> Void)?
    
    var body: some View {
        NavigationView {
            Form {
                Section("Category Details") {
                    TextField("Category Name", text: $name)
                        .textFieldStyle(.roundedBorder)
                }
                
                Section("Weekly Target") {
                    HStack {
                        Image(systemName: "target")
                            .foregroundColor(.orange)
                        Text("Tasks per week")
                        Spacer()
                        Stepper(value: $weeklyTarget, in: 0...50) {
                            Text("\(weeklyTarget)")
                                .frame(minWidth: 30)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section("Color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 16) {
                        ForEach(Category.CategoryColor.allCases, id: \.self) { color in
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    selectedColor = color
                                }
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
                                        .scaleEffect(selectedColor == color ? 1.1 : 1.0)
                                    
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
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    private func saveCategory() {
        let newCategory = Category(name: name, color: selectedColor, weeklyTarget: weeklyTarget)
        
        modelContext.insert(newCategory)
        
        do {
            try modelContext.save()
            
            // Call the callback to notify parent and auto-select
            onCategoryCreated?(newCategory)
            
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

#Preview {
    do {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Category.self, ToDoTask.self, GlobalTargetSettings.self, configurations: config)

        let workCategory = Category(name: "Work", color: .Blue, weeklyTarget: 5)
        let personalCategory = Category(name: "Personal", color: .Green, weeklyTarget: 3)
        let urgentCategory = Category(name: "Urgent", color: .Red)

        container.mainContext.insert(workCategory)
        container.mainContext.insert(personalCategory)
        container.mainContext.insert(urgentCategory)

        return CategorySelectionView(selectedCategories: .constant([workCategory]))
            .modelContainer(container)
            .padding()
    } catch {
        return Text("Preview Error: \(error.localizedDescription)")
    }
}
