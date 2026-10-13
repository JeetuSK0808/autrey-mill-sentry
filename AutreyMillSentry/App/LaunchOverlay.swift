import SwiftUI

/// Leaf-green launch moment: the leaf grows in, the midrib draws, the eye opens, the name fades in,
/// then the whole thing lifts away to reveal the app. About 1.6 s. Reduce Motion: a plain fade.
struct LaunchOverlay: View {
    let onFinished: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var leafScale: CGFloat = 0.2
    @State private var rib: CGFloat = 0
    @State private var eye: CGFloat = 0
    @State private var titleShown = false
    @State private var lift = false
    @State private var glow = false

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.07, green: 0.30, blue: 0.20), Theme.forest, Color(red: 0.16, green: 0.52, blue: 0.34)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            Circle()
                .fill(RadialGradient(colors: [Theme.leaf.opacity(0.35), .clear], center: .center, startRadius: 10, endRadius: 260))
                .frame(width: 520, height: 520)
                .scaleEffect(glow ? 1.1 : 0.7)
                .opacity(glow ? 1 : 0)
            VStack(spacing: 28) {
                SentryMark(leafScale: leafScale, ribProgress: rib, eyeOpen: eye)
                    .frame(width: 220, height: 220)
                VStack(spacing: 8) {
                    Text("Mill Sentry")
                        .font(.system(.largeTitle, design: .rounded).weight(.bold))
                        .foregroundStyle(.white)
                    Text("Every visitor becomes a sentry")
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.85))
                }
                .opacity(titleShown ? 1 : 0)
                .offset(y: titleShown || reduceMotion ? 0 : 12)
            }
            .offset(y: -20)
        }
        .scaleEffect(lift && !reduceMotion ? 1.08 : 1)
        .opacity(lift ? 0 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Mill Sentry is starting")
        .task { await run() }
    }

    private func run() async {
        if reduceMotion {
            leafScale = 1; rib = 1; eye = 1; titleShown = true; glow = true
            try? await Task.sleep(for: .seconds(0.9))
            withAnimation(.easeOut(duration: 0.4)) { lift = true }
            try? await Task.sleep(for: .seconds(0.4))
            onFinished(); return
        }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.62)) { leafScale = 1; glow = true }
        try? await Task.sleep(for: .seconds(0.35))
        withAnimation(.easeInOut(duration: 0.45)) { rib = 1 }
        try? await Task.sleep(for: .seconds(0.3))
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { eye = 1 }
        try? await Task.sleep(for: .seconds(0.15))
        withAnimation(.easeOut(duration: 0.4)) { titleShown = true }
        try? await Task.sleep(for: .seconds(0.75))
        withAnimation(.easeIn(duration: 0.45)) { lift = true }
        try? await Task.sleep(for: .seconds(0.45))
        onFinished()
    }
}
