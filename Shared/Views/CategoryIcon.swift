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
        "moon.stars.fill",
        "moon.zzz.fill",
        "figure.walk",
        "figure.run",
        "figure.mind.and.body",
        "figure.strengthtraining.traditional",
        "figure.flexibility",
        "dumbbell.fill",
        "book.fill",
        "book.closed.fill",
        "pencil",
        "pencil.and.scribble",
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
        "carrot.fill",
        "pill.fill",
        "pills.fill",
        "mouth.fill",
        "wand.and.stars",
        "stethoscope",
        "phone.fill",
        "phone.fill.badge.plus",
        "envelope.fill",
        "calendar",
        "clock.fill",
        "clock.badge.checkmark",
        "alarm.fill",
        "timer",
        "checkmark.square.fill",
        "exclamationmark.triangle.fill",
        "music.note",
        "guitars.fill",
        "camera.fill",
        "gamecontroller.fill",
        "gift.fill",
        "dollarsign.circle.fill",
        "creditcard.fill",
        "chart.bar.fill",
        "doc.text.fill",
        "folder.fill",
        "paperplane.fill",
        "list.bullet.clipboard.fill",
        "gearshape.fill",
        "key.fill",
        "lock.fill",
        "magnifyingglass",
        "globe",
        "graduationcap.fill",
        "person.fill",
        "person.2.fill",
        "hands.sparkles.fill",
        "hand.thumbsup.fill",
        "face.smiling",
        "iphone.slash",
        "nosign",
        "broom.fill",
        "washer.fill",
        "sink.and.faucet.fill",
        "trash.fill",
        "dog.fill",
        "puzzlepiece.extension.fill",
        "target",
        "sparkles"
    ]

    /// Map a category name to a reasonable default icon suggestion.
    static func suggestedIconName(for categoryName: String) -> String? {
        let lowercased = categoryName.lowercased()
        let mapping: [(String, String)] = [
            // Work & productivity
            ("work", "briefcase.fill"),
            ("plan", "list.bullet.clipboard.fill"),
            ("review", "target"),
            ("goal", "target"),

            // Personal & social
            ("personal", "person.fill"),
            ("family", "person.2.fill"),
            ("friend", "phone.fill.badge.plus"),
            ("social", "person.2.fill"),
            ("message", "phone.fill.badge.plus"),
            ("call", "phone.fill.badge.plus"),
            ("compliment", "face.smiling"),
            ("kindness", "heart.fill"),
            ("gratitude", "hand.thumbsup.fill"),
            ("hobby", "puzzlepiece.extension.fill"),

            // Home & chores
            ("home", "house.fill"),
            ("clean", "broom.fill"),
            ("tidy", "broom.fill"),
            ("laundry", "washer.fill"),
            ("dishes", "sink.and.faucet.fill"),
            ("wash", "sink.and.faucet.fill"),
            ("trash", "trash.fill"),
            ("plant", "leaf.fill"),
            ("water", "drop.fill"),
            ("dog", "dog.fill"),
            ("bed", "bed.double.fill"),
            ("make the bed", "bed.double.fill"),

            // Health & body
            ("health", "heart.fill"),
            ("fitness", "dumbbell.fill"),
            ("exercise", "figure.strengthtraining.traditional"),
            ("workout", "figure.strengthtraining.traditional"),
            ("stretch", "figure.flexibility"),
            ("walk", "figure.walk"),
            ("sleep", "moon.zzz.fill"),
            ("bedtime", "moon.zzz.fill"),
            ("wake", "alarm.fill"),
            ("teeth", "mouth.fill"),
            ("brush", "mouth.fill"),
            ("floss", "wand.and.stars"),
            ("medication", "pill.fill"),
            ("vitamin", "pills.fill"),
            ("doctor", "stethoscope"),

            // Food & drink
            ("food", "fork.knife"),
            ("meal", "fork.knife"),
            ("healthy", "carrot.fill"),
            ("fruit", "carrot.fill"),
            ("vegetable", "carrot.fill"),
            ("sugar", "nosign"),
            ("fast", "clock.badge.checkmark"),
            ("coffee", "cup.and.saucer.fill"),
            ("hydration", "drop.fill"),

            // Mind & learning
            ("read", "book.fill"),
            ("learn", "graduationcap.fill"),
            ("study", "graduationcap.fill"),
            ("language", "globe"),
            ("write", "pencil.and.scribble"),
            ("journal", "book.closed.fill"),
            ("art", "paintbrush.fill"),
            ("creative", "paintbrush.fill"),
            ("music", "music.note"),
            ("instrument", "guitars.fill"),
            ("photo", "camera.fill"),
            ("game", "gamecontroller.fill"),
            ("meditate", "figure.mind.and.body"),
            ("mindfulness", "figure.mind.and.body"),

            // Money
            ("money", "dollarsign.circle.fill"),
            ("save", "dollarsign.circle.fill"),
            ("expense", "creditcard.fill"),
            ("finance", "chart.bar.fill"),
            ("budget", "chart.bar.fill"),

            // Time & urgency
            ("urgent", "exclamationmark.triangle.fill"),
            ("travel", "car.fill"),
            ("bike", "bicycle"),

            // Digital wellbeing
            ("phone", "iphone.slash"),
            ("social media", "iphone.slash"),
            ("screen", "iphone.slash")
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
    @State private var customIconName: String = ""

    private var filteredIcons: [String] {
        if searchText.isEmpty { return CategoryIcon.suggestions }
        return CategoryIcon.suggestions.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }

    private var isValidCustomIcon: Bool {
        let trimmed = customIconName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }
        return UIImage(systemName: trimmed) != nil
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

                if filteredIcons.isEmpty {
                    VStack(spacing: 8) {
                        Text("No matching icons")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        Text("Try typing a custom SF Symbol name below")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                }

                customIconSection
            }

            if selectedIcon != nil {
                Button("Remove Icon") {
                    selectedIcon = nil
                }
                .padding(.vertical, 8)
            }
        }
    }

    private var customIconSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Custom Icon")
                .font(.headline)
                .padding(.horizontal)

            HStack(spacing: 12) {
                TextField("SF Symbol name", text: $customIconName)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                if isValidCustomIcon {
                    Button("Use") {
                        selectedIcon = customIconName.trimmingCharacters(in: .whitespaces)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(.horizontal)

            HStack(spacing: 12) {
                CategoryIcon.image(for: customIconName.trimmingCharacters(in: .whitespaces))
                    .frame(width: 32, height: 32)
                    .foregroundStyle(isValidCustomIcon ? Color.primary : Color.secondary)

                if customIconName.isEmpty {
                    Text("Enter any SF Symbol name to preview it")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if isValidCustomIcon {
                    Text("Valid SF Symbol")
                        .font(.caption)
                        .foregroundStyle(.green)
                } else {
                    Text("Not a valid SF Symbol name")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
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
