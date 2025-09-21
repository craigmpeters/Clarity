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
                                
                    ForEach(allCategories, id: \.id) { category in
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
}

