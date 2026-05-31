import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var deepLink: DeepLinkRouter
    @StateObject private var todayVM = TodayViewModel()
    @Environment(\.scenePhase) private var scenePhase

    @State private var selectedTab = 0
    @State private var showingSearch = false
    @State private var showingVoiceRecorder = false

    private let indigo = Color(red: 0.31, green: 0.27, blue: 0.90)

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                TodayView(vm: todayVM)
                    .navigationDestination(for: Person.self) { p in
                        PersonDetailView(person: p)
                    }
            }
            .tabItem {
                Label("Today", systemImage: "tray.full")
            }
            .badge(todayVM.count == 0 ? 0 : todayVM.count)
            .tag(0)

            NavigationStack {
                PeopleListView()
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button {
                                showingSearch = true
                            } label: {
                                Image(systemName: "magnifyingglass")
                            }
                            .tint(indigo)
                        }
                    }
            }
            .tabItem {
                Label("People", systemImage: "person.2")
            }
            .tag(1)

            NavigationStack {
                CompaniesListView()
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button {
                                showingSearch = true
                            } label: {
                                Image(systemName: "magnifyingglass")
                            }
                            .tint(indigo)
                        }
                    }
            }
            .tabItem {
                Label("Companies", systemImage: "building.2")
            }
            .tag(2)

            NavigationStack {
                DiscussionsListView()
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button {
                                showingSearch = true
                            } label: {
                                Image(systemName: "magnifyingglass")
                            }
                            .tint(indigo)
                        }
                    }
            }
            .tabItem {
                Label("Discussions", systemImage: "point.3.connected.trianglepath.dotted")
            }
            .tag(3)

            NavigationStack {
                FeedView()
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button {
                                showingSearch = true
                            } label: {
                                Image(systemName: "magnifyingglass")
                            }
                            .tint(indigo)
                        }
                    }
            }
            .tabItem {
                Label("Feed", systemImage: "list.bullet.rectangle")
            }
            .tag(4)

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
            .tag(5)
        }
        .tint(indigo)
        .overlay(alignment: .bottomTrailing) {
            // Floating voice-memo FAB — visible across all tabs.
            Button {
                showingVoiceRecorder = true
            } label: {
                Image(systemName: "mic.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(indigo)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.18), radius: 6, x: 0, y: 3)
            }
            .padding(.trailing, 20)
            // Lifted above the tab bar.
            .padding(.bottom, 76)
            .accessibilityLabel("Record voice memo")
        }
        .sheet(isPresented: $showingVoiceRecorder) {
            VoiceRecordingView()
        }
        .onReceive(NotificationCenter.default.publisher(for: .kontaktiPresentVoiceRecorder)) { _ in
            showingVoiceRecorder = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .kontaktiTodayShouldRefresh)) { _ in
            Task { await todayVM.load() }
        }
        .sheet(isPresented: $showingSearch) {
            SearchView { _ in
                showingSearch = false
            }
        }
        // Share-extension deep link: kontakti://link-social?…
        .sheet(item: $deepLink.pendingLinkSocial) { payload in
            LinkSocialPickerView(payload: payload) { _ in
                deepLink.clearPendingLinkSocial()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await todayVM.load() }
                NotificationCenter.default.post(name: .kontaktiDidBecomeActive, object: nil)
            }
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthViewModel())
        .environmentObject(DeepLinkRouter.shared)
}
