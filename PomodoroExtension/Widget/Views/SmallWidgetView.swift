//
//  SmallWidgetView.swift
//  PomodoroExtensionExtension
//
//  Created by Craig Peters on 02/09/2025.
//

import SwiftUI

struct SmallTaskWidgetView: View {
    let entry: TaskWidgetEntry
    
    var body: some View {
        Link(destination: widgetURL) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: entry.filter.systemImage)
                        .font(.title3)
                        .foregroundStyle(entry.filter.color)
                    Spacer()
                }
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(entry.taskCount)")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    
                    Text(entry.filter.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
        }
    }
    
    private var widgetURL: URL {
        URL(string: "clarity://tasks?filter=\(entry.filter.rawValue)")!
    }
}
