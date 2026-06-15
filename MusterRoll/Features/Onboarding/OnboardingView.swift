import SwiftUI

/// First-launch welcome flow — local-first intro, import guidance, and quick-start actions.
@MainActor
struct OnboardingView: View {
    enum Completion {
        case dismiss
        case loadSample
        case openSettings
    }

    var onComplete: (Completion) -> Void

    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @State private var page = 0

    @ScaledMetric(relativeTo: .title2) private var heroDiameter: CGFloat = 112
    @ScaledMetric(relativeTo: .title) private var heroIconSize: CGFloat = 48

    private struct Page: Identifiable {
        let id: Int
        let symbol: String
        let title: String
        let subtitle: String
        let body: String
    }

    private let pages: [Page] = [
        Page(
            id: 0,
            symbol: "shield.lefthalf.filled",
            title: AppInfo.displayName,
            subtitle: "Your painting campaign HQ",
            body: "Track armies, units, squad members, and every stage of your hobby pipeline — all in one place."
        ),
        Page(
            id: 1,
            symbol: "lock.iphone",
            title: "Stays on your device",
            subtitle: "No account required",
            body: "Your collection lives locally on this iPhone or iPad. Nothing is uploaded or synced to a server."
        ),
        Page(
            id: 2,
            symbol: "square.and.arrow.down",
            title: "Bring your data",
            subtitle: "Import from the web app",
            body: "Import army and paint CSV files, or restore a full JSON backup from Settings → Data. Formats match the web app’s exports."
        ),
        Page(
            id: 3,
            symbol: "sparkles",
            title: "Ready to muster",
            subtitle: "Pick how you’d like to begin",
            body: "Explore with sample armies and paints, import your own files from Settings, or jump straight into an empty collection."
        ),
    ]

    private var largeText: Bool { dynamicTypeSize.isAccessibilitySize }

    /// iPhone landscape and other height-constrained layouts.
    private var compactHeight: Bool { verticalSizeClass == .compact }

    /// Side-by-side hero + copy when width helps and height is tight.
    private var widePageLayout: Bool { compactHeight && !largeText }

    private var contentMaxWidth: CGFloat { widePageLayout ? 760 : .infinity }

    private var horizontalPadding: CGFloat {
        if widePageLayout { return 32 }
        return largeText ? 20 : 28
    }

    private var effectiveHeroDiameter: CGFloat {
        if widePageLayout { return min(heroDiameter, 72) }
        if largeText { return min(heroDiameter, 80) }
        return min(heroDiameter, 128)
    }

    private var effectiveHeroIconSize: CGFloat {
        if widePageLayout { return min(heroIconSize, 32) }
        if largeText { return min(heroIconSize, 36) }
        return min(heroIconSize, 52)
    }

    var body: some View {
        NavigationStack {
            TabView(selection: $page) {
                ForEach(pages) { item in
                    pageContent(item)
                        .tag(item.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: page)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                footer
                    .padding(.horizontal, widePageLayout ? 32 : 24)
                    .padding(.top, compactHeight ? 8 : 12)
                    .padding(.bottom, compactHeight ? 10 : 16)
                    .background {
                        onboardingBackground
                            .ignoresSafeArea(edges: .bottom)
                    }
            }
            .background { onboardingBackground.ignoresSafeArea() }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if page < pages.count - 1 {
                        Button("Skip") { onComplete(.dismiss) }
                            .accessibilityIdentifier("onboardingSkip")
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func pageContent(_ item: Page) -> some View {
        ScrollView {
            Group {
                if widePageLayout {
                    HStack(alignment: .center, spacing: 28) {
                        heroMark(for: item)
                        textBlock(item, alignment: .leading)
                    }
                } else {
                    VStack(spacing: largeText ? 20 : 28) {
                        heroMark(for: item)
                            .padding(.top, largeText ? 4 : 16)
                        textBlock(item, alignment: .center)
                    }
                }
            }
            .frame(maxWidth: contentMaxWidth)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, widePageLayout ? 8 : 0)
            .padding(.bottom, 8)

            if item.id == 3 {
                featureHighlights(twoColumn: widePageLayout)
                    .frame(maxWidth: contentMaxWidth)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, horizontalPadding)
                    .padding(.bottom, 8)
            }
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private func textBlock(_ item: Page, alignment: TextAlignment) -> some View {
        VStack(spacing: 10) {
            Text(item.title)
                .font(.system(widePageLayout ? .title : .largeTitle, design: .serif).weight(.bold))
                .multilineTextAlignment(alignment)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            Text(item.subtitle)
                .font(widePageLayout ? .headline.weight(.medium) : .title3.weight(.medium))
                .foregroundStyle(Color(hex: palette.gold))
                .multilineTextAlignment(alignment)
                .fixedSize(horizontal: false, vertical: true)

            Text(item.body)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(alignment)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .center)
    }

    private func featureHighlights(twoColumn: Bool) -> some View {
        let rows: [(String, String)] = [
            ("shield.lefthalf.filled", "Collection progress & filters"),
            ("paintpalette.fill", "Paint inventory with low-stock alerts"),
            ("chart.pie", "Overview stats across your armies"),
            ("rectangle.on.rectangle", "Home-screen widget for sprue count"),
        ]

        return Group {
            if twoColumn {
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                    alignment: .leading,
                    spacing: 12
                ) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                        highlightRow(row.0, row.1)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                        highlightRow(row.0, row.1)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private func highlightRow(_ symbol: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(Color(hex: palette.gold))
                .frame(minWidth: 24, alignment: .center)
                .accessibilityHidden(true)

            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func heroMark(for item: Page) -> some View {
        if item.id == 0 {
            ZStack {
                Circle()
                    .fill(Color(hex: palette.gold).opacity(0.14))
                    .frame(width: effectiveHeroDiameter, height: effectiveHeroDiameter)
                Circle()
                    .strokeBorder(Color(hex: palette.gold).opacity(0.28), lineWidth: 1)
                    .frame(width: effectiveHeroDiameter, height: effectiveHeroDiameter)
                BrandCrest(size: effectiveHeroDiameter * 0.72)
            }
            .accessibilityLabel(AppInfo.displayName)
        } else {
            heroSymbol(item.symbol)
        }
    }

    private func heroSymbol(_ name: String) -> some View {
        ZStack {
            Circle()
                .fill(Color(hex: palette.gold).opacity(0.14))
                .frame(width: effectiveHeroDiameter, height: effectiveHeroDiameter)
            Circle()
                .strokeBorder(Color(hex: palette.gold).opacity(0.28), lineWidth: 1)
                .frame(width: effectiveHeroDiameter, height: effectiveHeroDiameter)
            Image(systemName: name)
                .font(.system(size: effectiveHeroIconSize, weight: .medium))
                .foregroundStyle(Color(hex: palette.gold))
                .symbolRenderingMode(.hierarchical)
                .accessibilityHidden(true)
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var footer: some View {
        if widePageLayout {
            wideFooter
        } else {
            stackedFooter
        }
    }

    private var stackedFooter: some View {
        VStack(spacing: largeText ? 12 : 16) {
            pageIndicator
            footerActions
        }
    }

    private var wideFooter: some View {
        VStack(spacing: 10) {
            if page < pages.count - 1 {
                HStack(spacing: 16) {
                    pageIndicator
                    Spacer(minLength: 0)
                    Button("Continue") { page += 1 }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.regular)
                        .accessibilityIdentifier("onboardingContinue")
                }
            } else {
                HStack(spacing: 12) {
                    Button("Load sample data") { onComplete(.loadSample) }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.regular)
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("onboardingLoadSample")

                    Button("Open Settings") { onComplete(.openSettings) }
                        .buttonStyle(.bordered)
                        .controlSize(.regular)
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("onboardingOpenSettings")
                }

                HStack(spacing: 12) {
                    pageIndicator
                    Spacer(minLength: 0)
                    Button("Continue to app") { onComplete(.dismiss) }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("onboardingContinue")
                }
            }
        }
        .frame(maxWidth: contentMaxWidth)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var footerActions: some View {
        if page < pages.count - 1 {
            Button("Continue") { page += 1 }
                .buttonStyle(.borderedProminent)
                .controlSize(largeText ? .regular : .large)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("onboardingContinue")
        } else {
            VStack(spacing: 10) {
                Button("Load sample data") { onComplete(.loadSample) }
                    .buttonStyle(.borderedProminent)
                    .controlSize(largeText ? .regular : .large)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("onboardingLoadSample")

                Button("Open Settings") { onComplete(.openSettings) }
                    .buttonStyle(.bordered)
                    .controlSize(largeText ? .regular : .large)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("onboardingOpenSettings")

                Button("Continue to app") { onComplete(.dismiss) }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("onboardingContinue")
            }
        }
    }

    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(pages) { item in
                Capsule()
                    .fill(item.id == page ? Color(hex: palette.gold) : Color.secondary.opacity(0.25))
                    .frame(width: item.id == page ? 22 : 8, height: 8)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: page)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Page \(page + 1) of \(pages.count)")
    }

    private var onboardingBackground: some View {
        ZStack {
            Color(hex: palette.bg)
            RadialGradient(
                colors: [
                    Color(hex: palette.gold).opacity(0.12),
                    Color(hex: palette.bg).opacity(0),
                ],
                center: compactHeight ? .leading : .top,
                startRadius: 40,
                endRadius: 420
            )
        }
    }
}

#Preview("Default") {
    OnboardingView { _ in }
        .preferredColorScheme(.dark)
}

#Preview("Landscape", traits: .landscapeLeft) {
    OnboardingView { _ in }
        .preferredColorScheme(.dark)
}

#Preview("Large Text") {
    OnboardingView { _ in }
        .preferredColorScheme(.dark)
        .environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("Landscape Large Text", traits: .landscapeLeft) {
    OnboardingView { _ in }
        .preferredColorScheme(.dark)
        .environment(\.dynamicTypeSize, .accessibility3)
}
