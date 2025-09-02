// CategorySettingsView.swift with full edit capabilities

import SwiftUI
import SwiftData

struct CategorySettingsView: View {
    @Query private var categories: [Category]
    @Query private var globalSettings: [GlobalTargetSettings]
    @Environment(\.modelContext) private var modelContext
    @State private var globalTarget: Int = 0
    @State private var showingAddCategory = false
    @State private var editingCategory: Category?
    
    private var currentGlobalSettings: GlobalTargetSettings? {
        globalSettings.first
    }
    
    var body: some View {
        NavigationView {
            Form {
                // Global Weekly Target Section
                Section {
                    HStack {
                        Label("Global Weekly Target", systemImage: "target")
                            .foregroundStyle(.orange)
                        
                        Spacer()
                        
                        Stepper(value: $globalTarget, in: 0...100) {
                            HStack {
                                TextField("", value: $globalTarget, format: .number)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 50)
                                    .multilineTextAlignment(.center)
                                    .keyboardType(.numberPad)
                                Text("tasks")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("Overall Target")
                } footer: {
                    Text("Set a target for total tasks to complete each week across all categories")
                        .font(.caption)
                }
                
                // Individual Category Targets
                Section {
                    ForEach(categories) { category in
                        CategoryTargetRow(
                            category: category,
                            onEdit: {
                                editingCategory = category
                            }
                        )
                    }
                    .onDelete(perform: deleteCategories)
                    
                    Button(action: { showingAddCategory = true }) {
                        Label("Add Category", systemImage: "plus.circle.fill")
                            .foregroundStyle(.blue)
                    }
                } header: {
                    Text("Category Targets")
                } footer: {
                    Text("Tap a category to edit name and color. Adjust targets with +/- buttons.")
                        .font(.caption)
                }
                
                // Target Summary
                if !categories.isEmpty {
                    Section("Target Summary") {
                        HStack {
                            Text("Sum of Category Targets")
                            Spacer()
                            Text("\(categories.reduce(0) { $0 + $1.weeklyTarget })")
                                .foregroundStyle(.secondary)
                        }
                        
                        if globalTarget > 0 {
                            HStack {
                                Text("Global Target")
                                Spacer()
                                Text("\(globalTarget)")
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Categories & Targets")
            .onAppear {
                loadGlobalSettings()
            }
            .onChange(of: globalTarget) { _, newValue in
                saveGlobalTarget(newValue)
            }
            .sheet(isPresented: $showingAddCategory) {
                AddCategoryView()
            }
            .sheet(item: $editingCategory) { category in
                EditCategoryView(category: category)
            }
        }
    }
    
    private func loadGlobalSettings() {
        if let settings = currentGlobalSettings {
            globalTarget = settings.weeklyGlobalTarget
        } else {
            let settings = GlobalTargetSettings()
            modelContext.insert(settings)
            try? modelContext.save()
        }
    }
    
    private func saveGlobalTarget(_ value: Int) {
        if let settings = currentGlobalSettings {
            settings.weeklyGlobalTarget = value
        } else {
            let settings = GlobalTargetSettings(weeklyGlobalTarget: value)
            modelContext.insert(settings)
        }
        try? modelContext.save()
    }
    
    private func deleteCategories(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(categories[index])
        }
        try? modelContext.save()
    }
}

// Updated CategoryTargetRow with edit button
struct CategoryTargetRow: View {
    @Bindable var category: Category
    @Environment(\.modelContext) private var modelContext
    let onEdit: () -> Void
    
    var body: some View {
        HStack {
            // Tappable category info
            Button(action: onEdit) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(category.color.SwiftUIColor)
                        .frame(width: 16, height: 16)
                    
                    Text(category.name)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            // Target adjustment buttons
            HStack(spacing: 4) {
                Button(action: { decrementTarget() }) {
                    Image(systemName: "minus.circle")
                        .foregroundStyle(category.weeklyTarget > 0 ? .blue : .gray)
                }
                .buttonStyle(.plain)
                .disabled(category.weeklyTarget == 0)
                
                Text("\(category.weeklyTarget)")
                    .frame(minWidth: 30)
                    .font(.system(.body, design: .monospaced))
                
                Button(action: { incrementTarget() }) {
                    Image(systemName: "plus.circle")
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
                
                Text("/ week")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func incrementTarget() {
        category.weeklyTarget += 1
        try? modelContext.save()
    }
    
    private func decrementTarget() {
        if category.weeklyTarget > 0 {
            category.weeklyTarget -= 1
            try? modelContext.save()
        }
    }
}

// Edit Category View for name and color
struct EditCategoryView: View {
    @Bindable var category: Category
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var name: String
    @State private var selectedColor: Category.CategoryColor
    @State private var weeklyTarget: Int
    
    init(category: Category) {
        self.category = category
        self._name = State(initialValue: category.name)
        self._selectedColor = State(initialValue: category.color)
        self._weeklyTarget = State(initialValue: category.weeklyTarget)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Category Name") {
                    TextField("Category Name", text: $name)
                        .textFieldStyle(.roundedBorder)
                }
                
                Section("Weekly Target") {
                    HStack {
                        Image(systemName: "target")
                            .foregroundStyle(.orange)
                        Text("Tasks per week")
                        Spacer()
                        Stepper(value: $weeklyTarget, in: 0...50) {
                            Text("\(weeklyTarget)")
                                .frame(minWidth: 30)
                                .foregroundStyle(.secondary)
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
                
                Section("Preview") {
                    HStack {
                        Circle()
                            .fill(selectedColor.SwiftUIColor)
                            .frame(width: 20, height: 20)
                        Text(name.isEmpty ? "Category Name" : name)
                            .foregroundColor(name.isEmpty ? .secondary : .primary)
                        Spacer()
                        if weeklyTarget > 0 {
                            Text("\(weeklyTarget) / week")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Edit Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveChanges()
                    }
                    .disabled(name.isEmpty)
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    private func saveChanges() {
        category.name = name
        category.color = selectedColor
        category.weeklyTarget = weeklyTarget
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("Failed to save category changes: \(error)")
        }
    }
}
