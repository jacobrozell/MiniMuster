import SwiftUI

/// In-app privacy policy (bundled markdown).
struct PrivacyPolicyView: View {
    private let markdown: String

    init() {
        if let url = Bundle.main.url(forResource: "PRIVACY", withExtension: "md"),
           let text = try? String(contentsOf: url, encoding: .utf8) {
            markdown = text
        } else {
            markdown = "# Privacy Policy\n\nUnable to load the privacy policy file."
        }
    }

    var body: some View {
        ScrollView {
            Text(attributed)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .textSelection(.enabled)
        }
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var attributed: AttributedString {
        (try? AttributedString(markdown: markdown, options: .init(interpretedSyntax: .full))) ??
            AttributedString(markdown)
    }
}

#Preview {
    NavigationStack { PrivacyPolicyView() }
}
