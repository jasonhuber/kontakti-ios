import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var authVM: AuthViewModel

    var body: some View {
        Group {
            if authVM.isLoading {
                ZStack {
                    Color(.systemBackground).ignoresSafeArea()
                    VStack(spacing: 16) {
                        Image("AppLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 72, height: 72)
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
                        ProgressView()
                            .scaleEffect(1.2)
                    }
                }
            } else if authVM.isAuthenticated {
                if authVM.needsOnboarding {
                    OnboardingView()
                } else {
                    MainTabView()
                }
            } else {
                NavigationStack {
                    LoginView()
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: authVM.isAuthenticated)
        .animation(.easeInOut(duration: 0.2), value: authVM.isLoading)
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthViewModel())
}
