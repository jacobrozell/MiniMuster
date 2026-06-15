import TipKit

/// Shown once on an army unit list when units can be advanced.
struct SwipeAdvanceTip: Tip {
    var title: Text { Text("Advance with a swipe") }

    var message: Text? {
        Text("Swipe right on a unit to move it to the next painting stage.")
    }

    var image: Image? { Image(systemName: "arrow.right.circle") }
}
