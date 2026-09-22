// TabRootContainer.swift
// Per-tab container: hosts each tab's NavigationStack, and on iOS 27.1+ regular width
// (iPad, unfolded Duo) wraps the tab content in an ArrangementView so the companion
// sidebar sits alongside. Compact widths and older OS versions render content directly.

import SwiftUI

struct TabRootContainer<Content: View>: View {
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @ViewBuilder let content: () -> Content

    var body: some View {
        NavigationStack {
            Group {
                if #available(iOS 27.1, *), hSizeClass == .regular {
                    ArrangementView {
                        content()
                    } secondary: {
                        CompanionSidebarView()
                            .splitArrangementLayoutSize(
                                minWidth: 300,
                                idealWidth: 340,
                                maxWidth: 380
                            )
                    }
                    .arrangementViewStyle(.split.axes(.horizontal))
                } else {
                    content()
                }
            }
        }
    }
}
