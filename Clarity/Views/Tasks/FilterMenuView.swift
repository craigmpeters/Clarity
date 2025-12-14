//
//  FilterMenuView.swift
//  Clarity
//
//  Created by Craig Peters on 18/09/2025.
//

import SwiftUI

struct FilterMenuView: View {
    @Binding var selectedFilter: ToDoTask.TaskFilter
    @Binding var selectedCategory: Category?
    let allCategories: [Category]

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
                        
            if !allCategories.isEmpty {
                Section("Category") {
                    Button(action: { selectedCategory = nil }) {
                        HStack {
                            Text("All Categories")
                            if selectedCategory == nil {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                                
                    ForEach(getCategoryFilter(allCategories), id: \.id) { category in
                        Button(action: { selectedCategory = category }) {
                            HStack {
                                Circle()
                                    .fill(category.color!.SwiftUIColor)
                                    .frame(width: 12, height: 12)
                                Text(category.name!)
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
    
    func getCategoryFilter(_ categories: [Category]) -> [Category] {
        let defaults = UserDefaults(suiteName: "group.me.craigpeters.clarity")
        
        // Read settings; if unavailable, return the input
        guard
            let raw = defaults?.object(forKey: "ClarityFocusFilter"),
            let settings = raw as? CategoryFilterSettings
        else {
            return categories
        }
        
        // Build a set of selected category names from settings
        let selectedNames = Set(settings.Categories.compactMap { $0.name })
        
        // If there are no selected names, just return the original categories
        if selectedNames.isEmpty {
            return categories
        }
        
        // Determine whether settings represent a hide mode. We compare to a string to avoid depending on an unknown enum type.
        let isHideMode: Bool
        if let showOrHide = (settings as AnyObject).value(forKey: "showOrHide") as? String {
            isHideMode = (showOrHide.lowercased() == "hide")
        } else {
            // Default to show mode if unknown
            isHideMode = false
        }
        
        if isHideMode {
            // Hide the listed categories
            return categories.filter { category in
                guard let name = category.name else { return true }
                return !selectedNames.contains(name)
            }
        } else {
            // Show only the listed categories
            return categories.filter { category in
                guard let name = category.name else { return false }
                return selectedNames.contains(name)
            }
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

