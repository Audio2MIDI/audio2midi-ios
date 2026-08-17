import SwiftUI

struct RootView: View {
    @Bindable var model: AppModel
    @AppStorage("onboarding.completed") private var completedOnboarding = false

    private var skipsOnboarding: Bool {
        ProcessInfo.processInfo.arguments.contains("-skipOnboarding")
    }

    var body: some View {
        Group {
            if !completedOnboarding && !skipsOnboarding {
                OnboardingView { completedOnboarding = true }
            } else {
                switch model.phase {
                case .launching: LaunchView()
                case .signedOut: SignInView(model: model)
                case .signedIn: MainTabs(model: model)
                }
            }
        }
        .background(StudioColor.black.ignoresSafeArea())
        .task { if model.phase == .launching { await model.bootstrap() } }
        .onReceive(NotificationCenter.default.publisher(for: .didRegisterForPush)) { note in
            if let token = note.object as? String { Task { await model.registerPush(token: token) } }
        }
        .onReceive(NotificationCenter.default.publisher(for: .didFailToRegisterForPush)) { note in
            if let message = note.object as? String { model.errorMessage = message }
        }
        .alert("Something went wrong", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) { Button("OK", role: .cancel) {} } message: { Text(model.errorMessage ?? "") }
    }
}

private struct LaunchView: View {
    var body: some View {
        VStack(spacing: 18) {
            Wordmark()
            ProgressView().tint(StudioColor.blue)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(StudioColor.black)
    }
}

struct OnboardingView: View {
    let complete: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Wordmark().padding(.top, 24)
            Spacer()
            ZStack {
                ForEach(0..<9) { index in
                    Capsule()
                        .fill(index == 4 ? StudioColor.blue : Color.white.opacity(0.18))
                        .frame(width: 7, height: CGFloat([42, 72, 98, 58, 132, 82, 108, 66, 46][index]))
                        .offset(x: CGFloat(index - 4) * 18)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 190)
            Text("Turn any sound\ninto something playable.")
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .tracking(-1.4)
                .padding(.bottom, 18)
                .accessibilityIdentifier("onboarding.title")
            Text("Upload a track, record an idea, or paste a link. Get a piano cover, notation, chords, or separated stems.")
                .font(.system(size: 17))
                .foregroundStyle(StudioColor.secondary)
                .lineSpacing(4)
            Spacer()
            Button("Start creating", action: complete)
                .buttonStyle(StudioButtonStyle(prominent: true))
                .accessibilityIdentifier("onboarding.continue")
                .padding(.bottom, 12)
        }
        .padding(.horizontal, 24)
        .background(StudioColor.black.ignoresSafeArea())
    }
}

struct MainTabs: View {
    @Bindable var model: AppModel
    var body: some View {
        TabView(selection: $model.selectedTab) {
            NavigationStack { LibraryView(model: model) }
                .tabItem { Label("Library", systemImage: "square.stack") }.tag(0)
            NavigationStack { CreateView(model: model) }
                .tabItem { Label("Create", systemImage: "plus.circle.fill") }.tag(1)
            NavigationStack { AccountView(model: model) }
                .tabItem { Label("Account", systemImage: "person.crop.circle") }.tag(2)
        }
        .toolbarBackground(StudioColor.surface, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
    }
}
