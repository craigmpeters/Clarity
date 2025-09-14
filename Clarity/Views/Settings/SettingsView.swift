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
            
            Section("About") {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                    Text("Version")
                    Spacer()
                    buildInformation()
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
    
    private func buildInformation() -> Text {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown Version"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown Build"
        
        return Text("\(version) (\(build))")
        
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
                    CategoryRowView(
                        category: category,
                        onEdit: { categoryToEdit = category },
                        onDelete: {
                            categoryToDelete = category
                            showingDeleteAlert = true
                        }
                    )
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
            deleteAlertMessage(for: categoryToDelete)
        }
    }
    
    private func deleteAlertMessage(for category: Category?) -> Text {
        guard let category = category else { return Text("") }
        
        let taskCount = category.tasks?.count ?? 0
        let categoryName = category.name ?? "Unnamed Category"
        let message = "Remove '\(categoryName)' from \(taskCount) task\(taskCount == 1 ? "" : "s") and delete the category?"
        
        return Text(message)
    }
    
    private func deleteCategory(_ category: Category) {
        // Remove this category from all tasks that use it
        if let tasks = category.tasks {
            for task in tasks {
                task.categories?.removeAll { $0.name == category.name }
            }
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

// MARK: - CategoryRowView
struct CategoryRowView: View {
    let category: Category
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            categoryColorCircle
            categoryNameText
            Spacer()
            taskCountText
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onEdit()
        }
        .swipeActions(edge: .trailing) {
            deleteButton
            editButton
        }
    }
    
    // MARK: - View Components
    private var categoryColorCircle: some View {
        Circle()
            .fill(category.color.SwiftUIColor)
            .frame(width: 20, height: 20)
    }
    
    private var categoryNameText: some View {
        Text(category.name ?? "Unnamed Category")
    }
    
    private var taskCountText: some View {
        let count = category.tasks?.count ?? 0
        return Text("\(count) tasks")
            .font(.caption)
            .foregroundColor(.secondary)
    }
    
    private var deleteButton: some View {
        Button(role: .destructive, action: onDelete) {
            Label("Delete", systemImage: "trash")
        }
    }
    
    private var editButton: some View {
        Button(action: onEdit) {
            Label("Edit", systemImage: "pencil")
        }
        .tint(.blue)
    }
}

#Preview {
    SettingsView()
}
