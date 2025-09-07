//
//  CategoryPickerSheet.swift
//  Clarity
//
//  Created by Craig Peters on 02/09/2025.
//

import SwiftUI
import SwiftData
import Foundation

// MARK: - Category Picker Sheet
struct CategoryPickerSheet: View {
    @Binding var selectedCategories: [Category]
    @Query private var allCategories: [Category]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("Select Categories") {
                    ForEach(allCategories) { category in
                        Button(action: { toggleCategory(category) }) {
                            HStack {
                                Circle()
                                    .fill(category.color.SwiftUIColor)
                                    .frame(width: 16, height: 16)
                                
                                Text(category.name)
                                    .foregroundStyle(.primary)
                                
                                Spacer()
                                
                                if selectedCategories.contains(where: { $0.id == category.id }) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Categories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
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
