import SwiftUI

struct PaintsTab: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var selectedPaintId: UUID?
    @State private var compactPath = NavigationPath()

    private var usesSplitLayout: Bool {
        AdaptiveLayout.usesSplitNavigation(horizontalSizeClass)
    }

    private var sidebarWidth: (min: CGFloat, ideal: CGFloat, max: CGFloat) {
        AdaptiveLayout.splitColumnWidth(dynamicType: dynamicTypeSize)
    }

    var body: some View {
        Group {
            if usesSplitLayout {
                splitView
            } else {
                compactView
            }
        }
    }

    private var splitView: some View {
        NavigationSplitView {
            PaintListView(selectedPaintId: $selectedPaintId)
                .navigationSplitViewColumnWidth(min: sidebarWidth.min, ideal: sidebarWidth.ideal, max: sidebarWidth.max)
        } detail: {
            if let id = selectedPaintId {
                PaintDetailView(paintId: id)
            } else {
                ContentUnavailableView("Select a Paint", systemImage: "paintpalette",
                                       description: Text("Choose a paint from the list."))
            }
        }
    }

    private var compactView: some View {
        NavigationStack(path: $compactPath) {
            PaintListView(
                selectedPaintId: $selectedPaintId,
                onSelectPaint: { selectedPaintId = $0 }
            )
            .navigationDestination(for: PaintRoute.self) { route in
                if case .paint(let paintId) = route {
                    PaintDetailView(paintId: paintId)
                }
            }
        }
    }
}
