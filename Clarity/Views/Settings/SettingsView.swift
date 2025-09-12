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
        NavigationStack {
            List {
                ForEach(allCategories, id: \.id) { category in
                    CategoryRow(category: category, onEdit: {
                        categoryToEdit = category
                    }, onDelete: {
                        categoryToDelete = category
                        showingDeleteAlert = true
                    })
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
                Text("Remove '\(category.name)' from \(category.tasks?.count ?? 0) tasks and delete the category?")
            }
        }
    }
    
    private func deleteCategory(_ category: Category) {
        // Remove this category from all tasks that use it
        if let tasks = category.tasks {
            for task in tasks {
                var cats = task.categories ?? []
                cats.removeAll { $0.id == category.id }
                task.categories = cats
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

private struct CategoryRow: View {
    let category: Category
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack {
            Circle()
                .fill(category.color.SwiftUIColor)
                .frame(width: 20, height: 20)

            Text(category.name)

            Spacer()

            Text("\(category.tasks?.count ?? 0) tasks")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .contentShape(Rectangle())
        .onTapGesture { onEdit() }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) { onDelete() } label: {
                Label("Delete", systemImage: "trash")
            }

            Button { onEdit() } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(.blue)
        }
    }
}

#Preview {
    SettingsView()
}
