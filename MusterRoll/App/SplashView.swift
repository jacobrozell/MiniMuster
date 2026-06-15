import SwiftUI

/// Branded splash shown immediately after the system launch screen.
struct SplashView: View {
    var body: some View {
        ZStack {
            Color("LaunchBackground")
                .ignoresSafeArea()
            BrandCrest(size: 160)
        }
        .accessibilityIdentifier("splashScreen")
    }
}

#Preview {
    SplashView()
}
