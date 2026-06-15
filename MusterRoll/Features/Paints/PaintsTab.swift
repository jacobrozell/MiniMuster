import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct PaintsTab: View {
    @State private var selectedPaintId: UUID?
    @State private var compactPath = NavigationPath()

    private var usesSplitLayout: Bool {
#if canImport(UIKit)
        UIDevice.current.userInterfaceIdiom == .pad
#else
        false
#endif
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
                .navigationSplitViewColumnWidth(min: 320, ideal: 380, max: 440)
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
                onSelectPaint: { paintId in
                    selectedPaintId = paintId
                    compactPath.append(PaintRoute.paint(paintId))
                }
            )
            .navigationDestination(for: PaintRoute.self) { route in
                if case .paint(let paintId) = route {
                    PaintDetailView(paintId: paintId)
                }
            }
        }
    }
}
