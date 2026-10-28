import SwiftUI
import XCGLogger

struct TabRootContainer<Content: View>: View {
    @Environment(\.horizontalSizeClass)
    private var hSizeClass

    @Environment(\.verticalSizeClass)
    private var vSizeClass

    private var logger: XCGLogger {
        LogManager.shared.log
    }

    @ViewBuilder let content: () -> Content

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let showSidebar =
                    hSizeClass == .regular && vSizeClass == .regular

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
                .onChange(of: geometry.size, initial: true) { _, size in
                    logger.debug(
                        """
                        Window: \(size.width) × \(size.height)
                        Horizontal: \(String(describing: hSizeClass))
                        Vertical: \(String(describing: vSizeClass))
                        """)
                }
            }

        }
    }
}
