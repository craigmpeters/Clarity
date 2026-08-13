//
//  FilterMenuView.swift
//  Clarity
//
//  Created by Craig Peters on 18/09/2025.
//

import SwiftUI
import OSLog

struct FilterMenuView: View {
    @Binding var selectedFilter: ToDoTask.TaskFilter
    @Binding var selectedCategory: Category?
    let allCategories: [Category]

    // MARK: - Derived data
    private var focusSettings: CategoryFilterSettings? {
        let defaults = UserDefaults(suiteName: "group.me.craigpeters.clarity")
        let focusData = defaults?.data(forKey: "ClarityFocusFilter")
        return focusData.flatMap { try? JSONDecoder().decode(CategoryFilterSettings.self, from: $0) }
    }

    private var filteredCategories: [Category] {
        let focusedNames = focusSettings?.Categories.compactMap { $0.name } ?? []
        let isHide = focusSettings?.showOrHide == .hide
        let allNames = Set(allCategories.compactMap { $0.name })
        let allowedNames = CategoryFilter.allowedNames(allNames: allNames, focusedNames: focusedNames, isHide: isHide)
        return allCategories.filter { cat in
            if let name = cat.name { return allowedNames.contains(name) }
            return false
        }
    }
    
    // let onFilterChange: (ToDoStore.TaskFilter) -> Void
    
    var body: some View {
        Menu {
            Section("Due Date") {
                ForEach(ToDoTask.TaskFilter.allCases, id: \.self) { filter in
                    Button(action: {
                        selectedFilter = filter
                        //onFilterChange(filter)
                    }) {
                        HStack {
                            Text(filter.rawValue)
                            if selectedFilter == filter {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
                        
            if !filteredCategories.isEmpty {
                Section("Category") {
                    Button(action: { selectedCategory = nil }) {
                        HStack {
                            Text("All Categories")
                            if selectedCategory == nil {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                                
                    ForEach(filteredCategories, id: \.id) { category in
                        Button(action: { selectedCategory = category }) {
                            HStack {
                                if let iconName = category.iconName, !iconName.isEmpty {
                                    CategoryIcon.image(for: iconName)
                                        .frame(width: 12, height: 12)
                                        .foregroundStyle((category.color?.SwiftUIColor) ?? .gray)
                                } else {
                                    Circle()
                                        .fill((category.color?.SwiftUIColor) ?? .gray)
                                        .frame(width: 12, height: 12)
                                }
                                Text(category.name ?? "Unnamed")
                                if selectedCategory?.name == category.name {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .foregroundStyle(.blue)
        }
    }
    
//    func getCategoryFilter(_ categories: [Category]) -> [Category] {
//        let defaults = UserDefaults(suiteName: "group.me.craigpeters.clarity")
//        
//        // Read settings; if unavailable, return the input
//        guard
//            let raw = defaults?.object(forKey: "ClarityFocusFilter"),
//            let settings = raw as? CategoryFilterSettings
//        else {
//            return categories
//        }
//        
//        // Build a set of selected category names from settings
//        let selectedNames = Set(settings.Categories.compactMap { $0.name })
//        
//        // If there are no selected names, just return the original categories
//        if selectedNames.isEmpty {
//            return categories
//        }
//        
//        // Determine whether settings represent a hide mode. We compare to a string to avoid depending on an unknown enum type.
//        let isHideMode: Bool
//        if let showOrHide = (settings as AnyObject).value(forKey: "showOrHide") as? String {
//            isHideMode = (showOrHide.lowercased() == "hide")
//        } else {
//            // Default to show mode if unknown
//            isHideMode = false
//        }
//        
//        if isHideMode {
//            // Hide the listed categories
//            return categories.filter { category in
//                guard let name = category.name else { return true }
//                return !selectedNames.contains(name)
//            }
//        } else {
//            // Show only the listed categories
//            return categories.filter { category in
//                guard let name = category.name else { return false }
//                return selectedNames.contains(name)
//            }
//        }
//    }
}

// MARK: - Category filter helper

enum CategoryFilter {
    static func allowedNames(allNames: Set<String>, focusedNames: [String], isHide: Bool) -> Set<String> {
        let focused = Set(focusedNames)
        if isHide {
            return allNames.subtracting(focused)
        } else {
            return focused.isEmpty ? [] : allNames.intersection(focused)
        }
    }
}

#if DEBUG
#Preview {
    
    @Previewable @State var selectedFilter: ToDoTask.TaskFilter = ToDoTask.TaskFilter.allCases.first!
    @Previewable @State var selectedCategory: Category? = nil
    FilterMenuView(
        selectedFilter: $selectedFilter,
        selectedCategory: $selectedCategory,
        allCategories: PreviewData.shared.getCategories()
    )
}
#endif
