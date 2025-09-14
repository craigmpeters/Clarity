import SwiftUI
import SwiftData

struct SettingsView: View {
    @State private var showingCategoryManagement = false
    
    var body: some View {
        Form {
            Section("Categories") {
                NavigationLink(destination: CategorySettingsView()) {
                    HStack {
                        Image(systemName: "tag")
                            .foregroundColor(.blue)
                        Text("Manage Categories & Targets")
                    }
                }
                .foregroundColor(.primary)
            }
            
            // ToDo: Version 1.1 Stuff
//            Section("General") {
//                HStack {
//                    Image(systemName: "bell")
//                        .foregroundColor(.orange)
//                    Text("Notifications")
//                    Spacer()
//                    // Add notification settings here
//                }
//                
//                HStack {
//                    Image(systemName: "paintbrush")
//                        .foregroundColor(.purple)
//                    Text("Appearance")
//                    Spacer()
//                    // Add appearance settings here
//                }
//            }
            
            Section("About") {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                    Text("Version")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }
            }
            // Development tools section - only shows in DEBUG builds
            #if DEBUG
            DevelopmentSection()
            #endif
        }
        .sheet(isPresented: $showingCategoryManagement) {
            CategoryManagementView()
        }
    }
}

struct CategoryManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var allCategories: [Category]
    @State private var showingAddCategory = false
    @State private var categoryToEdit: Category?
    @State private var categoryToDelete: Category?
    @State private var showingDeleteAlert = false
    
    var body: some View {
        NavigationView {
            List {
                ForEach(allCategories, id: \.id) { category in
                    HStack {
                        Circle()
                            .fill(category.color.SwiftUIColor)
                            .frame(width: 20, height: 20)
                        
                        Text(category.name)
                        
                        Spacer()
                        
                        Text("\(category.tasks.count) tasks")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        categoryToEdit = category
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            categoryToDelete = category
                            showingDeleteAlert = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        
                        Button {
                            categoryToEdit = category
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
                }
            }
            .navigationTitle("Categories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddCategory = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddCategory) {
            AddCategoryView()
        }
        .sheet(item: $categoryToEdit) { category in
            EditCategoryView(category: category)
        }
        .alert("Delete Category", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {
                categoryToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let category = categoryToDelete {
                    deleteCategory(category)
                }
                categoryToDelete = nil
            }
        } message: {
            if let category = categoryToDelete {
                Text("Remove '\(category.name)' from \(category.tasks.count) tasks and delete the category?")
            }
        }
    }
    
    private func deleteCategory(_ category: Category) {
        // Remove this category from all tasks that use it
        for task in category.tasks {
            task.categories.removeAll { $0.name == category.name }
        }
        
        // Delete the category
        modelContext.delete(category)
        
        do {
            try modelContext.save()
        } catch {
            print("Failed to delete category: \(error)")
        }
    }
}

//struct EditCategoryView: View {
//    @Environment(\.modelContext) private var modelContext
//    @Environment(\.dismiss) private var dismiss
//    @Query private var allCategories: [Category]
//    
//    let category: Category
//    @State private var name: String
//    @State private var selectedColor: Category.CategoryColor
//    
//    init(category: Category) {
//        self.category = category
//        self._name = State(initialValue: category.name)
//        self._selectedColor = State(initialValue: category.color)
//    }
//    
//    private var isNameValid: Bool {
//        !name.isEmpty && (name == category.name || !allCategories.contains { $0.name.lowercased() == name.lowercased() })
//    }
//    
//    var body: some View {
//        NavigationView {
//            Form {
//                Section("Category Details") {
//                    TextField("Category Name", text: $name)
//                }
//                
//                Section("Color") {
//                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 16) {
//                        ForEach(Category.CategoryColor.allCases, id: \.self) { color in
//                            Button(action: {
//                                selectedColor = color
//                            }) {
//                                VStack(spacing: 4) {
//                                    Circle()
//                                        .fill(color.SwiftUIColor)
//                                        .frame(width: 32, height: 32)
//                                        .overlay(
//                                            Circle()
//                                                .stroke(Color.white, lineWidth: 2)
//                                                .opacity(selectedColor == color ? 1 : 0)
//                                        )
//                                        .overlay(
//                                            Circle()
//                                                .stroke(Color.primary, lineWidth: 1)
//                                                .opacity(selectedColor == color ? 1 : 0)
//                                        )
//                                    
//                                    Text(color.rawValue)
//                                        .font(.caption2)
//                                        .foregroundColor(selectedColor == color ? color.SwiftUIColor : .secondary)
//                                }
//                            }
//                            .buttonStyle(PlainButtonStyle())
//                        }
//                    }
//                    .padding(.vertical, 8)
//                }
//                
//                if category.tasks.count > 0 {
//                    Section {
//                        Text("This category is used by \(category.tasks.count) task\(category.tasks.count == 1 ? "" : "s")")
//                            .font(.caption)
//                            .foregroundColor(.secondary)
//                    }
//                }
//            }
//            .navigationTitle("Edit Category")
//            .navigationBarTitleDisplayMode(.inline)
//            .toolbar {
//                ToolbarItem(placement: .navigationBarLeading) {
//                    Button("Cancel") {
//                        dismiss()
//                    }
//                }
//                
//                ToolbarItem(placement: .navigationBarTrailing) {
//                    Button("Save") {
//                        saveChanges()
//                    }
//                    .disabled(!isNameValid)
//                }
//            }
//        }
//    }
//    
//    private func saveChanges() {
//        category.name = name
//        category.color = selectedColor
//        
//        do {
//            try modelContext.save()
//            dismiss()
//        } catch {
//            print("Failed to update category: \(error)")
//        }
//    }
//}

#Preview {
    SettingsView()
}
