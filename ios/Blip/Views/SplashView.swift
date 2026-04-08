import SwiftUI

struct SplashView: View {
    @Binding var isActive: Bool
    @State private var opacity = 0.0
    @State private var scale = 0.8

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(BlipColors.accentPurple)

                Text("bzap")
                    .font(.system(size: 48, weight: .black, design: .monospaced))
                    .foregroundStyle(BlipColors.accentPurple)
            }
            .scaleEffect(scale)
            .opacity(opacity)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                opacity = 1.0
                scale = 1.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.easeIn(duration: 0.3)) {
                    isActive = false
                }
            }
        }
    }
}
