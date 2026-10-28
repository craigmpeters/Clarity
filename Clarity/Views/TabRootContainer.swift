import SwiftUI

struct TabRootContainer<Content: View>: View {
    @Environment(\.horizontalSizeClass)
    private var hSizeClass

    @ViewBuilder let content: () -> Content

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let size = geometry.size

                let showSidebar =
                    hSizeClass == .regular && size.width > size.height && size.height >= 600

                Group {
                    if #available(iOS 27.1, *), showSidebar {
                        ArrangementView {
                            content()
                                .padding(.trailing, 16)
                                .background(
                                    Color(uiColor: .systemGroupedBackground)
                                )
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
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity
                )
            }
        }
    }
}
