import SwiftUI

struct PaintsTab: View {
    @State private var selectedPaintId: UUID?

    var body: some View {
        NavigationSplitView {
            PaintListView(selectedPaintId: $selectedPaintId)
                .navigationSplitViewColumnWidth(min: 280, ideal: 320)
        } detail: {
            if let id = selectedPaintId {
                PaintDetailView(paintId: id)
            } else {
                ContentUnavailableView("Select a Paint", systemImage: "paintpalette",
                                       description: Text("Choose a paint from the list."))
            }
        }
    }
}
