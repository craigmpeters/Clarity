//
//  TaskWidgetTitle.swift
//  Clarity
//
//  Created by Craig Peters on 14/09/2025.
//

import SwiftUI

    func TaskWidgetTitle(entry: TaskWidgetEntry) -> HStack<TupleView<(some View, Spacer, Text)>> {
        return // Header
            HStack {
                Label(entry.filter.rawValue, systemImage: "checkmark.square")
                    .font(.headline)
                    .foregroundStyle(TaskFilterOption.filterColor[entry.filter] ?? .primary)
                
                Spacer()
                
                Text("\(entry.todos.count) tasks")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
    }

