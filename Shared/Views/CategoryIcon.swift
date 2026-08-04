//
//  CategoryIcon.swift
//  Clarity
//
//  Created by OpenCode on 04/08/2026.
//

import SwiftUI

struct CategoryIcon {
    /// A curated set of SF Symbol names suitable for categories/habits.
    static let suggestions: [String] = [
        "star.fill",
        "heart.fill",
        "bolt.fill",
        "flame.fill",
        "drop.fill",
        "leaf.fill",
        "sun.max.fill",
        "moon.fill",
        "figure.walk",
        "figure.run",
        "figure.mind.and.body",
        "dumbbell.fill",
        "book.fill",
        "pencil",
        "paintbrush.fill",
        "brain.head.profile",
        "laptopcomputer",
        "briefcase.fill",
        "house.fill",
        "car.fill",
        "bicycle",
        "bed.double.fill",
        "fork.knife",
        "cup.and.saucer.fill",
        "pill.fill",
        "stethoscope",
        "phone.fill",
        "envelope.fill",
        "calendar",
        "clock.fill",
        "timer",
        "checkmark.square.fill",
        "exclamationmark.triangle.fill",
        "music.note",
        "camera.fill",
        "gamecontroller.fill",
        "gift.fill",
        "dollarsign.circle.fill",
        "creditcard.fill",
        "chart.bar.fill",
        "doc.text.fill",
        "folder.fill",
        "paperplane.fill",
        "gearshape.fill",
        "key.fill",
        "lock.fill",
        "magnifyingglass",
        "globe",
        "person.fill",
        "person.2.fill",
        "hands.sparkles.fill",
        "sparkles"
    ]

    /// Map a category name to a reasonable default icon suggestion.
    static func suggestedIconName(for categoryName: String) -> String? {
        let lowercased = categoryName.lowercased()
        let mapping: [(String, String)] = [
            ("work", "briefcase.fill"),
            ("personal", "person.fill"),
            ("home", "house.fill"),
            ("health", "heart.fill"),
            ("fitness", "dumbbell.fill"),
            ("exercise", "figure.run"),
            ("walk", "figure.walk"),
            ("sleep", "bed.double.fill"),
            ("water", "drop.fill"),
            ("hydration", "drop.fill"),
            ("food", "fork.knife"),
            ("meal", "fork.knife"),
            ("coffee", "cup.and.saucer.fill"),
            ("read", "book.fill"),
            ("learn", "book.fill"),
            ("study", "book.fill"),
            ("write", "pencil"),
            ("art", "paintbrush.fill"),
            ("creative", "paintbrush.fill"),
            ("music", "music.note"),
            ("photo", "camera.fill"),
            ("game", "gamecontroller.fill"),
            ("money", "dollarsign.circle.fill"),
            ("finance", "chart.bar.fill"),
            ("plan", "calendar"),
            ("urgent", "exclamationmark.triangle.fill"),
            ("travel", "car.fill"),
            ("bike", "bicycle"),
            ("meditate", "brain.head.profile"),
            ("medication", "pill.fill"),
            ("doctor", "stethoscope")
        ]
        for (key, icon) in mapping {
            if lowercased.contains(key) {
                return icon
            }
        }
        return nil
    }

    /// Render a category icon as an Image, falling back to a tag when none is set.
    @MainActor
    static func image(for iconName: String?) -> some View {
        Group {
            if let iconName, !iconName.isEmpty, UIImage(systemName: iconName) != nil {
                Image(systemName: iconName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "tag")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
        }
    }
}

struct CategoryIconPicker: View {
    @Binding var selectedIcon: String?
    @State private var searchText: String = ""

    private var filteredIcons: [String] {
        if searchText.isEmpty { return CategoryIcon.suggestions }
        return CategoryIcon.suggestions.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 0) {
            SearchBar(text: $searchText, placeholder: "Search icons")

            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                    ForEach(filteredIcons, id: \.self) { icon in
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                selectedIcon = icon
                            }
                        }) {
                            CategoryIcon.image(for: icon)
                                .frame(width: 28, height: 28)
                                .foregroundStyle(selectedIcon == icon ? Color.white : Color.primary)
                                .padding(10)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(selectedIcon == icon ? Color.accentColor : Color(.systemGray6))
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .accessibilityLabel(icon.replacingOccurrences(of: ".", with: " "))
                    }
                }
                .padding()
            }

            if selectedIcon != nil {
                Button("Remove Icon") {
                    selectedIcon = nil
                }
                .padding(.vertical, 8)
            }
        }
    }
}

private struct SearchBar: View {
    @Binding var text: String
    var placeholder: String = "Search"

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField(placeholder, text: $text)
            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(8)
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding(.horizontal)
        .padding(.top, 8)
    }
}

#if DEBUG
#Preview {
    @Previewable @State var icon: String? = "star.fill"
    CategoryIconPicker(selectedIcon: .constant(icon))
}
#endif
