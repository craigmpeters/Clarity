//
//  TaskRowView.swift
//  Clarity
//
//  Created by Craig Peters on 18/09/2025.
//

import SwiftUI
struct TaskRowView: View {
    let task: ToDoTask
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onComplete: () -> Void
    let onStartTimer: () -> Void
    
    @State private var showingDeleteAlert = false
    @State private var isDismissing = false
    
<<<<<<< HEAD
    private func formatDate(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        formatter.doesRelativeDateFormatting = true
        return formatter.string(from: date)
    }
    
=======
>>>>>>> Hotfix
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(task.name)
                    .lineLimit(1)
                Spacer()
                RecurrenceIndicatorBadge(task: task)
            }
                
            HStack(spacing: 6) {
                ForEach(task.categories) { category in
                    Text(category.name)
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(category.color.SwiftUIColor)
                        )
                        .foregroundColor(category.color.contrastingTextColor)
                }
                Spacer()
<<<<<<< HEAD
                Text(formatDate(date: task.due))
                    .foregroundStyle(.secondary)
=======
                RelativeDateText(date: task.due)
>>>>>>> Hotfix
            }
        }
        .opacity(isDismissing ? 0 : 1)
        .offset(x: isDismissing ? 40 : 0)
        .animation(.spring(response: 0.25, dampingFraction: 0.9), value: isDismissing)
        .contentShape(Rectangle())
        .onTapGesture(perform: onEdit)
        .swipeActions(edge: .trailing) {
            Button {
                showingDeleteAlert = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .tint(.red)
        }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            Button(action: onStartTimer, label: {
                Label("Start Timer", systemImage: "timer")
            })
            .tint(.blue)
            
            Button(action: {
                #if canImport(UIKit)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                #endif
                withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                    isDismissing = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                        onComplete()
                    }
                }
            }, label: {
                Label("Complete", systemImage: "checkmark")
            })
            .tint(.green)
        }
        .confirmationDialog(
            "Are you sure you want to delete \(task.name)?",
            isPresented: $showingDeleteAlert,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                withAnimation {
                    onDelete()
                }
            }
            Button("Cancel", role: .cancel) { }
        }
    }
    
    
}
