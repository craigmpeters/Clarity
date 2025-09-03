//
//  SmallWidgetView.swift
//  PomodoroExtensionExtension
//
//  Created by Craig Peters on 02/09/2025.
//

import SwiftUI

struct SmallWidgetView: View {
    let entry: TaskWidgetEntry
    
    var body: some View {
        Link(destination: widgetURL) {
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: entry.filter.systemImage)
                        .font(.title3)
                        .foregroundStyle(entry.filter.accentColor)
                    Spacer()
                    Image("clarity")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24)
                }
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(entry.taskCount)")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    
                    HStack(spacing: 4) {
                        Text(entry.category?.name ?? entry.filter.rawValue)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        
                        if entry.category != nil {
                            Circle()
                                .fill(Category.CategoryColor(rawValue: entry.category!.colorRawValue)?.SwiftUIColor ?? .gray)
                                .frame(width: 8, height: 8)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
        }
        .widgetURL(widgetURL)
    }
    
    private var widgetURL: URL {
        var components = URLComponents(string: "clarity://tasks")!
        components.queryItems = [
            URLQueryItem(name: "filter", value: entry.filter.rawValue),
            URLQueryItem(name: "categoryId", value: entry.category?.id)
        ]
        return components.url!
    }
}
