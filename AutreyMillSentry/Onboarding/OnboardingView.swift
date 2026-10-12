import SwiftUI

/// Three screens max: what it does, the safety and data promise, then permission pre-prompts.
struct OnboardingView: View {
    @Environment(AppModel.self) private var app
    @State private var page = 0
    @State private var cameraAsked = false

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                pageOne.tag(0)
                pageTwo.tag(1)
                pageThree.tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            Button { next() } label: { Text(page == 2 ? "Start scanning" : "Continue").frame(maxWidth: .infinity).padding(.vertical, 8) }
                .buttonStyle(.borderedProminent).tint(Theme.forest).controlSize(.large)
                .padding(.horizontal, 24).padding(.bottom, 16)
                .accessibilityIdentifier("onboarding.next")
        }
        .background(Color(.systemBackground))
    }

    private func next() {
        if page < 2 { withAnimation { page += 1 } } else { app.settings.onboardingComplete = true }
    }

    private var pageOne: some View {
        OnboardingPage(symbol: "leaf.fill", title: "Every visitor becomes a sentry") {
            Text("Invasive plants like privet, English ivy and kudzu crowd out the native understory at Autrey Mill, which reduces the insects, berries and cover local wildlife depend on. Small patches are easy to remove. Large ones are not.")
            Text("**Spot** a plant with the camera. The app **verifies** it on your phone. Staff **act** on a ranked list. You get **told** when it's treated.")
        }
    }

    private var pageTwo: some View {
        OnboardingPage(symbol: "hand.raised.fill", title: "Our promise") {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(["No account, no name, no email, no tracking, no ads.", "Photos and locations stay on your phone until you tap Send.", "No people in photos. The app refuses shots with a person in them.", "Every result says \"AI suggestion, not a guarantee.\"", "Delete all your data any time in Settings."], id: \.self) {
                    Label($0, systemImage: "checkmark.circle.fill").font(.callout)
                }
            }
            Text(SafetyCopy.short).font(.footnote).foregroundStyle(.secondary)
            NavigationLink { PrivacyView() } label: { Text("How your data is used").font(.callout) }
        }
    }

    private var pageThree: some View {
        OnboardingPage(symbol: "camera.viewfinder", title: "Two permissions, both optional") {
            VStack(alignment: .leading, spacing: 14) {
                Label {
                    VStack(alignment: .leading) { Text("Camera").font(.headline); Text("To scan plants live. You can also pick a saved photo without it.").font(.callout) }
                } icon: { Image(systemName: "camera.fill").foregroundStyle(Theme.forest) }
                Label {
                    VStack(alignment: .leading) { Text("Location, only while using the app").font(.headline); Text("To pin reports on the trail map so staff can find the plant. Never in the background.").font(.callout) }
                } icon: { Image(systemName: "location.fill").foregroundStyle(Theme.forest) }
                Text("The system will ask when you first scan. You can change both later in Settings.").font(.footnote).foregroundStyle(.secondary)
            }
        }
    }
}

struct OnboardingPage<Content: View>: View {
    let symbol: String
    let title: String
    @ViewBuilder var content: Content
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Image(systemName: symbol).font(.system(size: 56)).foregroundStyle(Theme.forest).frame(maxWidth: .infinity)
                Text(title).font(.largeTitle.bold()).frame(maxWidth: .infinity, alignment: .leading)
                content
            }
            .padding(24)
        }
    }
}
