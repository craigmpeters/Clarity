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
                Label(entry.filter.rawValue, systemImage: entry.filter.systemImage)
                    .font(.headline)
                    .foregroundStyle(entry.filter.color)
                
                Spacer()
                
                Text("\(entry.taskCount) tasks")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
    }
