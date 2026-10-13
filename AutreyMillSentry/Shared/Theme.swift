import SwiftUI

/// Bold, graphic, memorable: strong greens, confident type, native components underneath.
enum Theme {
    static let forest = Color(red: 0.11, green: 0.42, blue: 0.29)
    static let forestDeep = Color(red: 0.07, green: 0.34, blue: 0.23)   // toolbar text on glass
    static let muted = Color.primary.opacity(0.72)                      // captions inside tinted cards
    static let leaf = Color(red: 0.55, green: 0.80, blue: 0.42)
    static let bark = Color(red: 0.36, green: 0.25, blue: 0.16)
    static let creek = Color(red: 0.16, green: 0.49, blue: 0.80)
    static let alert = Color(red: 0.80, green: 0.22, blue: 0.16)
    static let caution = Color(red: 0.93, green: 0.58, blue: 0.10)

    static func color(for status: ReportStatus) -> Color {
        switch status {
        case .new: return caution
        case .confirmed: return alert
        case .treated: return forest
        case .dismissed: return .gray
        }
    }

    /// Text colour for tinted badges: darker than the fill so it clears WCAG AA on the 18% tint.
    static func badgeText(for status: ReportStatus) -> Color {
        switch status {
        case .new: return Color(red: 0.52, green: 0.30, blue: 0.0)
        case .confirmed: return Color(red: 0.62, green: 0.14, blue: 0.10)
        case .treated: return Color(red: 0.07, green: 0.34, blue: 0.23)
        case .dismissed: return Color(red: 0.30, green: 0.30, blue: 0.32)
        }
    }
    static func badgeText(for tier: SpeciesTier) -> Color {
        switch tier {
        case .tier1: return Color(red: 0.62, green: 0.14, blue: 0.10)
        case .tier2: return Color(red: 0.52, green: 0.30, blue: 0.0)
        case .native: return Color(red: 0.07, green: 0.34, blue: 0.23)
        case .other: return Color(red: 0.30, green: 0.30, blue: 0.32)
        }
    }

    static func color(for tier: SpeciesTier) -> Color {
        switch tier {
        case .tier1: return alert
        case .tier2: return caution
        case .native: return forest
        case .other: return .secondary
        }
    }
}

/// Shape AND colour per status so colour-blind users can tell pins apart.
struct StatusPin: View {
    let status: ReportStatus
    var size: CGFloat = 30
    var body: some View {
        Image(systemName: status.symbolName)
            .font(.system(size: size * 0.6, weight: .bold))
            .foregroundStyle(.white)
            .contentTransition(.symbolEffect(.replace))
            .frame(width: size, height: size)
            .background(Theme.color(for: status), in: Circle())
            .overlay(Circle().stroke(.white, lineWidth: 2))
            .shadow(radius: 2)
            .animation(Motion.snappy, value: status)
            .popIn()
            .accessibilityLabel("\(status.title) report")
    }
}

struct StatusBadge: View {
    let status: ReportStatus
    var body: some View {
        Label(status.title, systemImage: status.symbolName)
            .contentTransition(.symbolEffect(.replace))
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(Theme.color(for: status).opacity(0.18), in: Capsule())
            .foregroundStyle(Theme.badgeText(for: status))
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// HStack that becomes a VStack at accessibility text sizes so nothing truncates.
struct AdaptiveHStack<Content: View>: View {
    @Environment(\.dynamicTypeSize) private var size
    var spacing: CGFloat = 8
    @ViewBuilder var content: Content
    var body: some View {
        if size.isAccessibilitySize {
            VStack(alignment: .leading, spacing: spacing) { content }
        } else {
            HStack(spacing: spacing) { content }
        }
    }
}

struct TierBadge: View {
    let tier: SpeciesTier
    var text: String {
        switch tier {
        case .tier1: return "Tuned species"
        case .tier2: return "Broad coverage"
        case .native: return "Native"
        case .other: return "Other"
        }
    }
    var body: some View {
        Text(text).font(.caption2.weight(.bold))
            .padding(.horizontal, 6).padding(.vertical, 3)
            .background(Theme.color(for: tier).opacity(0.15), in: Capsule())
            .foregroundStyle(Theme.badgeText(for: tier))
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct ConfidenceBar: View {
    let value: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = 0.0
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Calibrated confidence").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text("\(Int((shown * 100).rounded()))%").font(.caption.monospacedDigit().weight(.semibold))
                    .contentTransition(.numericText(value: shown))
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(.quaternary)
                    Capsule().fill(value >= 0.8 ? Theme.forest : value >= 0.5 ? Theme.caution : Theme.alert)
                        .frame(width: max(6, g.size.width * shown))
                }
            }.frame(height: 10)
        }
        .onAppear {
            if reduceMotion { shown = value } else { withAnimation(.easeOut(duration: 0.9).delay(0.15)) { shown = value } }
        }
        .onChange(of: value) { _, v in withAnimation(Motion.gentle) { shown = v } }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Calibrated confidence \(Int((value * 100).rounded())) percent")
    }
}

struct AIHonestyFooter: View {
    var body: some View {
        Label("AI suggestion, not a guarantee. Staff make the final call.", systemImage: "info.circle")
            .font(.footnote).foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct EmptyStateView: View {
    let symbol: String
    let title: String
    let message: String
    var body: some View {
        ContentUnavailableView { Label(title, systemImage: symbol) } description: { Text(message) }
    }
}

enum SafetyCopy {
    static let short = "Stay on marked trails. Do not touch or pick plants. Report it, do not remove it."
    static let lines = [
        "Stay on marked trails and follow posted preserve rules.",
        "Do not touch or pick plants: poison ivy, brambles and ticks are common.",
        "Watch your footing near the creek and on wet rocks.",
        "Supervise children and keep people out of your photos.",
        "Report it, do not remove it. Staff decide what to do.",
        "Do not enter closed areas or sensitive habitat.",
    ]
}

extension Image {
    init(cg: CGImage) { self.init(decorative: cg, scale: 1, orientation: .up) }
}

struct CGImageView: View {
    let image: CGImage?
    var contentMode: ContentMode = .fill
    var body: some View {
        Group {
            if let image {
                Image(cg: image).resizable().aspectRatio(contentMode: contentMode)
            } else {
                ZStack { Rectangle().fill(.quaternary); Image(systemName: "photo").foregroundStyle(.secondary) }
            }
        }
    }
}

/// Rounded card used across screens.
struct Card<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

extension Date {
    var shortDescription: String { formatted(date: .abbreviated, time: .shortened) }
}
