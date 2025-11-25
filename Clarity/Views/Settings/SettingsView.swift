import SwiftData
import SwiftUI

struct SettingsView: View {
    @State private var showingCategoryManagement = false
    @AppStorage("logViewerRuntimeEnabled") private var logViewerRuntimeEnabled = false
    @Environment(\.isLogViewerEnabled) private var isLogViewerEnabled

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

            // TODO: Version 1.1 Stuff
            Section("General") {
                HStack {
                    NavigationLink(destination: NotificationSettingsView()) {
                        Image(systemName: "bell")
                            .foregroundColor(.orange)
                        Text("Notifications")
                        Spacer()
                    }
                }
                HStack {
                    NavigationLink(destination: AppIconSettingsView()) {
                        Image(systemName: "paintbrush")
                            .foregroundColor(.green)
                        Text("Change App Icon")
                        Spacer()
                    }
                }
            }
            if isLogViewerEnabled {
                Section("Logging") {
                    Toggle(isOn: $logViewerRuntimeEnabled) {
                        HStack {
                            Image(systemName: "switch.2")
                                .foregroundColor(.purple)
                            Text("Enable Log Viewer")
                        }
                    }
                    
                    
                    if isLogViewerEnabled && logViewerRuntimeEnabled {
                        HStack {
                            NavigationLink(destination: LogView()) {
                                Image(systemName: "doc.text.magnifyingglass")
                                    .foregroundColor(.purple)
                                Text("View Logs")
                                Spacer()
                            }
                        }
                    }
                }
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

            #if DEBUG
//            Section("Connectivity Debug") {
//                Button("Request Tasks From Phone") {
//                    #if os(iOS)
//                    // No-op on iOS; tasks are stored locally
//                    print("iOS: Tasks are local; nothing to request.")
//                    #else
//                    ClarityWatchConnectivity.shared.requestTasksFromPhone()
//                    #endif
//                }
//                Button("Print Last Received Tasks") {
//                    let tasks = ClarityWatchConnectivity.shared.lastReceivedTasks
//                    print("Connectivity Debug: Received \(tasks.count) tasks")
//                    for t in tasks { print("- id: \(t.id), name: \(t.name), due: \(t.due))") }
//                }
//            }
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
                    CategorySettingsRow(
                        category: category,
                        onDelete: { deleteCategory(category) },
                        onEdit: { editCategory(category) }
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
            if let category = categoryToDelete {
                Text("Remove '\(category.name!)' from \(category.tasks!.count) tasks and delete the category?")
            }
        }
    }

    private func editCategory(_ category: Category) {
        print("Editing \(category.name ?? "")")
        categoryToEdit = category
    }

    private func deleteCategory(_ category: Category) {
        // Remove this category from all tasks that use it
        guard let tasks = category.tasks else { return }
        for task in tasks {
            task.categories!.removeAll { $0.name == category.name }
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

// struct EditCategoryView: View {
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
// }

struct AppIconSettingsView: View {
    struct AppIcon: Identifiable, Hashable {
        let id: String
        let displayName: String
        let previewImageName: String
        // id should match the alternate icon name in Info.plist (CFBundleAlternateIcons). Use "primary" for the default icon.
    }

    // Update this list to match the icons you have configured in your asset catalog and Info.plist.
    private let availableIcons: [AppIcon] = [
        .init(id: "Default", displayName: "Default", previewImageName: "Appicon-Preview-Default"),
        .init(id: "Pride", displayName: "Pride", previewImageName: "Appicon-Preview-Pride"),
        .init(id: "Autumn", displayName: "Autumn", previewImageName: "Appicon-Preview-Autumn"),
        .init(id: "Christmas", displayName: "Christmas", previewImageName: "Appicon-Preview-Christmas")
    ]

    @State private var currentIconName: String = "primary"
    @State private var isChanging = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section(footer: footerText) {
                ForEach(availableIcons) { icon in
                    HStack(spacing: 16) {
                        Image(icon.previewImageName)
                            .resizable()
                            .aspectRatio(1, contentMode: .fit)
                            .frame(width: 48, height: 48)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                            )

                        VStack(alignment: .leading) {
                            Text(icon.displayName)
                            if currentIconName == icon.id || (currentIconName == "primary" && icon.id == "primary") {
                                Text("Selected").font(.caption).foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        if currentIconName == icon.id || (currentIconName == "primary" && icon.id == "primary") {
                            Image(systemName: "checkmark").foregroundColor(.accentColor)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { select(icon: icon) }
                }
            }
        }
        .navigationTitle("App Icon")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: loadCurrentIcon)
        .alert("Couldn’t Change Icon", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            if let errorMessage { Text(errorMessage) }
        }
    }

    private var footerText: some View {
        Group {
            #if os(iOS)
            if !UIApplication.shared.supportsAlternateIcons {
                Text("This device does not support alternate app icons.")
            } else {
                Text("Choose a preferred app icon. You can change this anytime.")
            }
            #else
            Text("App icon selection is only available on iOS.")
            #endif
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
    }

    private func loadCurrentIcon() {
        #if os(iOS)
        if let name = UIApplication.shared.alternateIconName {
            currentIconName = name
        } else {
            currentIconName = "primary"
        }
        #else
        currentIconName = "primary"
        #endif
    }

    private func select(icon: AppIcon) {
        guard !isChanging else { return }
        #if os(iOS)
        guard UIApplication.shared.supportsAlternateIcons else { return }
        isChanging = true
        let targetName: String? = (icon.id == "primary") ? nil : icon.id
        UIApplication.shared.setAlternateIconName(targetName) { error in
            DispatchQueue.main.async {
                isChanging = false
                if let error = error {
                    errorMessage = error.localizedDescription
                } else {
                    currentIconName = icon.id
                }
            }
        }
        #else
        // No-op on non-iOS platforms
        #endif
    }
}

#Preview {
}
