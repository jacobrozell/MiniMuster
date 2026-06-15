import SwiftUI

/// Branded splash shown immediately after the system launch screen.
struct SplashView: View {
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    @State private var pulse = false

    @ScaledMetric(relativeTo: .largeTitle) private var crestDiameter: CGFloat = 132

    var body: some View {
        ZStack {
            splashBackground

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                crestHero
                    .padding(.bottom, 28)

                branding
                    .padding(.bottom, 36)

                loadingSection

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 48)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 16)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("splashScreen")
        .onAppear {
            pulse = !reduceMotion
            if reduceMotion {
                appeared = true
            } else {
                withAnimation(.easeOut(duration: 0.6)) {
                    appeared = true
                }
            }
        }
    }

    private var splashBackground: some View {
        ZStack {
            Color(hex: palette.bg)
                .ignoresSafeArea()

            RadialGradient(
                colors: [
                    Color(hex: palette.gold).opacity(0.18),
                    Color(hex: palette.bg).opacity(0),
                ],
                center: .top,
                startRadius: 20,
                endRadius: 420
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [
                    Color(hex: palette.blood).opacity(0.08),
                    Color(hex: palette.bg).opacity(0),
                ],
                center: .bottomTrailing,
                startRadius: 10,
                endRadius: 320
            )
            .ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color(hex: palette.bg).opacity(0),
                    Color(hex: palette.bg2).opacity(0.55),
                ],
                startPoint: .center,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }

    private var crestHero: some View {
        ZStack {
            Circle()
                .fill(Color(hex: palette.gold).opacity(0.12))
                .frame(width: crestDiameter, height: crestDiameter)
                .scaleEffect(pulse ? 1.06 : 0.94)
                .animation(
                    reduceMotion ? nil : .easeInOut(duration: 1.6).repeatForever(autoreverses: true),
                    value: pulse
                )

            Circle()
                .strokeBorder(Color(hex: palette.gold).opacity(0.35), lineWidth: 1.5)
                .frame(width: crestDiameter, height: crestDiameter)

            Circle()
                .strokeBorder(Color(hex: palette.gold).opacity(0.12), lineWidth: 8)
                .frame(width: crestDiameter * 1.18, height: crestDiameter * 1.18)

            BrandCrest(size: crestDiameter * 0.68)
        }
        .accessibilityLabel(AppInfo.displayName)
    }

    private var branding: some View {
        VStack(spacing: 10) {
            Text(AppInfo.displayName)
                .font(.system(.largeTitle, design: .serif).weight(.bold))
                .foregroundStyle(Color(hex: palette.ink))
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)

            Text("Track · Paint · Muster")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color(hex: palette.gold))
                .tracking(0.6)
                .multilineTextAlignment(.center)

            Text("Your painting campaign HQ")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var loadingSection: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.regular)
                .tint(Color(hex: palette.gold))
                .accessibilityIdentifier("splashLoading")

            Text("Mustering ranks…")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay {
            Capsule()
                .strokeBorder(Color(hex: palette.line).opacity(0.45), lineWidth: 0.5)
        }
    }
}

#Preview("Light") {
    SplashView()
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    SplashView()
        .preferredColorScheme(.dark)
}
