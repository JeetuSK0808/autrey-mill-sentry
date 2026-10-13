import SwiftUI

/// One place for the app's motion language: springy, short, purposeful, and off when Reduce Motion is on.
enum Motion {
    static let spring = Animation.spring(response: 0.45, dampingFraction: 0.8)
    static let bouncy = Animation.spring(response: 0.4, dampingFraction: 0.6)
    static let snappy = Animation.snappy(duration: 0.3)
    static let gentle = Animation.easeOut(duration: 0.5)
    static let stagger = 0.045   // seconds between rows
}

/// Scales the button down a touch while pressed. Used on every primary call to action.
struct PressableButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(Motion.snappy, value: configuration.isPressed)
    }
}

/// Solid forest-green call to action: white bold text on an opaque fill, so contrast does not depend on glass.
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.vertical, 14)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity)
            .background(Theme.forest.opacity(isEnabled ? 1 : 0.5), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(Motion.snappy, value: configuration.isPressed)
    }
}

/// Fades and slides a view in once, staggered by its index. With Reduce Motion it only fades.
struct StaggeredAppear: ViewModifier {
    let index: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false
    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown || reduceMotion ? 0 : 14)
            .onAppear {
                withAnimation(Motion.gentle.delay(Double(min(index, 12)) * Motion.stagger)) { shown = true }
            }
    }
}

/// Pops a view in with a spring (scale + fade). With Reduce Motion it only fades.
struct PopIn: ViewModifier {
    var delay: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false
    func body(content: Content) -> some View {
        content
            .scaleEffect(shown || reduceMotion ? 1 : 0.6)
            .opacity(shown ? 1 : 0)
            .onAppear { withAnimation(Motion.bouncy.delay(delay)) { shown = true } }
    }
}

extension View {
    func staggeredAppear(_ index: Int) -> some View { modifier(StaggeredAppear(index: index)) }
    func popIn(delay: Double = 0) -> some View { modifier(PopIn(delay: delay)) }
    func pressable() -> some View { buttonStyle(PressableButtonStyle()) }
    func primaryButton() -> some View { buttonStyle(PrimaryButtonStyle()) }
}

/// The app's mark, drawn in SwiftUI so it can animate: a leaf with a watchful eye.
struct LeafShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        let tip = CGPoint(x: rect.maxX, y: rect.midY)
        let stem = CGPoint(x: rect.minX, y: rect.midY)
        p.move(to: stem)
        p.addCurve(to: tip, control1: CGPoint(x: rect.minX + w * 0.15, y: rect.minY - h * 0.1), control2: CGPoint(x: rect.minX + w * 0.75, y: rect.minY - h * 0.05))
        p.addCurve(to: stem, control1: CGPoint(x: rect.minX + w * 0.75, y: rect.maxY + h * 0.05), control2: CGPoint(x: rect.minX + w * 0.15, y: rect.maxY + h * 0.1))
        p.closeSubpath()
        return p
    }
}

struct MidribShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        p.move(to: CGPoint(x: rect.minX + w * 0.05, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.minX + w * 0.31, y: rect.midY))
        p.move(to: CGPoint(x: rect.minX + w * 0.69, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.maxX - w * 0.05, y: rect.midY))
        return p
    }
}

/// Leaf + eye mark. `progress` 0...1 drives the midrib draw and eye opening; `scale` the leaf growth.
struct SentryMark: View {
    var leafScale: CGFloat = 1
    var ribProgress: CGFloat = 1
    var eyeOpen: CGFloat = 1
    var tint: Color = Theme.leaf
    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            ZStack {
                LeafShape()
                    .fill(LinearGradient(colors: [tint, tint.opacity(0.75)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: w * 0.9, height: h * 0.5)
                    .shadow(color: .black.opacity(0.25), radius: w * 0.04, y: w * 0.03)
                MidribShape()
                    .trim(from: 0, to: ribProgress)
                    .stroke(Theme.forest.opacity(0.7), style: StrokeStyle(lineWidth: max(2, w * 0.02), lineCap: .round))
                    .frame(width: w * 0.9, height: h * 0.5)
                ZStack {
                    Ellipse().fill(Color(red: 0.99, green: 0.99, blue: 0.96)).frame(width: w * 0.34, height: h * 0.2)
                    Circle().fill(Theme.forest).frame(width: w * 0.14)
                    Circle().fill(Color(red: 0.05, green: 0.1, blue: 0.07)).frame(width: w * 0.07)
                    Circle().fill(.white).frame(width: w * 0.03).offset(x: w * 0.015, y: -w * 0.025)
                }
                .scaleEffect(y: max(0.02, eyeOpen))
            }
            .rotationEffect(.degrees(-28))
            .scaleEffect(leafScale)
            .frame(width: w, height: h)
        }
        .accessibilityHidden(true)
    }
}
