//
//  CategorySettingsRow.swift
//  Clarity
//
//  Created by Craig Peters on 20/09/2025.
//

import SwiftUI
struct CategorySettingsRow: View {
    let category: Category
    let onDelete: () -> Void
    let onEdit: () -> Void
    
    @State private var showingDeleteAlert = false
    
    var body: some View {
        HStack {
            Circle()
                .fill(category.color!.SwiftUIColor)
                .frame(width: 20, height: 20)
            
            Text(category.name!)
            
            Spacer()
            
            Text("\(category.tasks?.count ?? 0) tasks")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onEdit)
        .swipeActions(edge: .trailing) {
            
            Button(role: .destructive) {
                showingDeleteAlert = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .tint(.red)
            
            Button {
                
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(.blue)
        }
        .confirmationDialog("Are you sure you want to delete \(category.name!)",
        isPresented: $showingDeleteAlert,
                            titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                withAnimation {
                    onDelete()
                }
            }
            Button("Cancel", role: .cancel) {}
        }

    }
}


                    
