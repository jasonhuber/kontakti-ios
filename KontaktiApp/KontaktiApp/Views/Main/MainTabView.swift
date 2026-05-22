import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @State private var selectedTab = 0
    @State private var showingSearch = false

    private let indigo = Color(red: 0.31, green: 0.27, blue: 0.90)

    var body: some View {
        TabView(selection: $selectedTab) {
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
            .tag(0)

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
            .tag(1)

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
                Label("Discussions", systemImage: "bubble.left.and.bubble.right")
            }
            .tag(2)

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
            .tag(3)
        }
        .tint(indigo)
        .sheet(isPresented: $showingSearch) {
            SearchView { result in
                showingSearch = false
                // Navigation to result is handled inside SearchView or caller
            }
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthViewModel())
}
