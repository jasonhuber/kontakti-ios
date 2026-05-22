import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var authVM: AuthViewModel

    var body: some View {
        Group {
            if authVM.isLoading {
                ZStack {
                    Color(.systemBackground).ignoresSafeArea()
                    VStack(spacing: 16) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color(hex: "#4F46E5"))
                                .frame(width: 72, height: 72)
                            Text("K")
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        }
                        ProgressView()
                            .scaleEffect(1.2)
                    }
                }
            } else if authVM.isAuthenticated {
                MainTabView()
            } else {
                LoginView()
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
