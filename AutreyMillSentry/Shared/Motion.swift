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

/// Map-pin teardrop: a circle whose tangents meet at the bottom tip.
struct PinShape: Shape {
    func path(in rect: CGRect) -> Path {
        let r = rect.width / 2
        let cx = rect.midX, cy = rect.minY + r
        let tipY = rect.maxY
        let a0 = acos(min(1, r / max(tipY - cy, r + 1)))
        let start = Double.pi / 2 + a0, end = Double.pi / 2 - a0 + 2 * Double.pi
        var p = Path()
        let n = 120
        for i in 0...n {
            let a = start + (end - start) * Double(i) / Double(n)
            let pt = CGPoint(x: cx + r * CGFloat(cos(a)), y: cy + r * CGFloat(sin(a)))
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.addLine(to: CGPoint(x: cx, y: tipY))
        p.closeSubpath()
        return p
    }
}

/// Leaf outline used inside the pin.
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

/// The app's mark: a pin with a leaf inside and a location ping at the tip. All parts animate independently.
struct SentryMark: View {
    var pinOffset: CGFloat = 0      // vertical offset of the pin (drop-in)
    var pinOpacity: Double = 1
    var leafScale: CGFloat = 1
    var ping: CGFloat = 0           // 0 = no ring, 1 = ring fully expanded and faded
    var ping2: CGFloat = 0
    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            let pinW = w * 0.56, pinH = h * 0.82
            let headR = pinW / 2
            ZStack {
                // location pings at the tip
                ForEach([ping, ping2], id: \.self) { pr in
                    Ellipse()
                        .stroke(Theme.leaf.opacity(Double(1 - pr) * 0.9), lineWidth: max(1.5, w * 0.012))
                        .frame(width: w * 0.12 + w * 0.6 * pr, height: (w * 0.12 + w * 0.6 * pr) * 0.32)
                        .position(x: w / 2, y: h * 0.91)
                        .opacity(pr > 0 && pr < 1 ? 1 : 0)
                }
                ZStack {
                    PinShape()
                        .fill(Color(red: 0.93, green: 0.96, blue: 0.89))
                        .shadow(color: .black.opacity(0.28), radius: w * 0.04, y: w * 0.03)
                    Circle()
                        .stroke(Color(red: 0.75, green: 0.89, blue: 0.63), lineWidth: max(1.5, w * 0.012))
                        .frame(width: headR * 1.8, height: headR * 1.8)
                        .position(x: pinW / 2, y: headR)
                    ZStack {
                        LeafShape().fill(Color(red: 0.13, green: 0.44, blue: 0.27))
                        MidribShape().stroke(Theme.leaf, style: StrokeStyle(lineWidth: max(1.5, w * 0.015), lineCap: .round))
                    }
                    .frame(width: headR * 1.25, height: headR * 0.65)
                    .rotationEffect(.degrees(-35))
                    .position(x: pinW / 2, y: headR + headR * 0.02)
                    .scaleEffect(leafScale)
                }
                .frame(width: pinW, height: pinH)
                .position(x: w / 2, y: h * 0.47)
                .offset(y: pinOffset)
                .opacity(pinOpacity)
            }
        }
        .accessibilityHidden(true)
    }
}

struct MidribShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + rect.width * 0.06, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.06, y: rect.midY))
        return p
    }
}
