import SwiftUI

/// In-app accessibility information (bundled markdown).
struct AccessibilityView: View {
    private let markdown: String

    init() {
        if let url = Bundle.main.url(forResource: "ACCESSIBILITY", withExtension: "md"),
           let text = try? String(contentsOf: url, encoding: .utf8) {
            markdown = text
        } else {
            markdown = "# Accessibility\n\nUnable to load the accessibility file."
        }
    }

    var body: some View {
        ScrollView {
            Text(attributed)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .textSelection(.enabled)
        }
        .navigationTitle("Accessibility")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var attributed: AttributedString {
        (try? AttributedString(markdown: markdown, options: .init(interpretedSyntax: .full))) ??
            AttributedString(markdown)
    }
}

#Preview {
    NavigationStack { AccessibilityView() }
}
