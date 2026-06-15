import SwiftUI

/// App crest mark — shared by launch screen, splash, and onboarding.
struct BrandCrest: View {
    var size: CGFloat = 160

    var body: some View {
        Image("CrestLogo")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
            .shadow(color: .black.opacity(0.14), radius: size * 0.06, y: size * 0.03)
            .accessibilityLabel("\(AppInfo.displayName) crest")
    }
}

#Preview {
    ZStack {
        Color("LaunchBackground").ignoresSafeArea()
        BrandCrest()
    }
}
