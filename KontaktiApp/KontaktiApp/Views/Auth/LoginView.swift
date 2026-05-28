import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var authVM: AuthViewModel

    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var isGoogleLoading = false
    @State private var errorMessage: String?
    @FocusState private var focusedField: Field?

    private enum Field { case email, password }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 32) {
                    Spacer(minLength: 60)

                    // Logo & Branding
                    VStack(spacing: 16) {
                        Image("AppLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 88, height: 88)
                            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                            .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)

                        VStack(spacing: 4) {
                            Text("Kontakti")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                            Text("Personal relationship intelligence")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }

                    // Form
                    VStack(spacing: 16) {
                        VStack(spacing: 12) {
                            // Email field
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Email")
                                    .font(.footnote)
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)
                                TextField("you@example.com", text: $email)
                                    .keyboardType(.emailAddress)
                                    .textContentType(.emailAddress)
                                    .autocapitalization(.none)
                                    .autocorrectionDisabled()
                                    .focused($focusedField, equals: .email)
                                    .submitLabel(.next)
                                    .onSubmit { focusedField = .password }
                                    .padding(14)
                                    .background(Color(.secondarySystemGroupedBackground))
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(focusedField == .email ? Color(hex: "#4F46E5") : Color.clear, lineWidth: 2)
                                    )
                            }

                            // Password field
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Password")
                                    .font(.footnote)
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)
                                SecureField("••••••••", text: $password)
                                    .textContentType(.password)
                                    .focused($focusedField, equals: .password)
                                    .submitLabel(.go)
                                    .onSubmit { Task { await signIn() } }
                                    .padding(14)
                                    .background(Color(.secondarySystemGroupedBackground))
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(focusedField == .password ? Color(hex: "#4F46E5") : Color.clear, lineWidth: 2)
                                    )
                            }
                        }

                        // Error message
                        if let error = errorMessage {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundColor(.red)
                                Text(error)
                                    .font(.footnote)
                                    .foregroundColor(.red)
                                Spacer()
                            }
                            .padding(12)
                            .background(Color.red.opacity(0.08))
                            .cornerRadius(10)
                        }

                        // Sign in button
                        Button {
                            Task { await signIn() }
                        } label: {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.85)
                                } else {
                                    Text("Sign in")
                                        .fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(canSubmit ? Color(hex: "#4F46E5") : Color(hex: "#4F46E5").opacity(0.5))
                            .foregroundColor(.white)
                            .cornerRadius(14)
                        }
                        .disabled(!canSubmit || isLoading)

                        NavigationLink(destination: RegisterView()) {
                            Text("Create account")
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color(.secondarySystemGroupedBackground))
                                .foregroundColor(Color(hex: "#4F46E5"))
                                .fontWeight(.semibold)
                                .cornerRadius(14)
                        }

                        HStack(spacing: 12) {
                            Rectangle().fill(Color(.separator)).frame(height: 1)
                            Text("or").font(.caption).foregroundColor(.secondary)
                            Rectangle().fill(Color(.separator)).frame(height: 1)
                        }

                        Button {
                            Task { await signInWithGoogle() }
                        } label: {
                            HStack(spacing: 10) {
                                if isGoogleLoading {
                                    ProgressView()
                                        .scaleEffect(0.85)
                                } else {
                                    Image(systemName: "g.circle")
                                        .font(.title3)
                                }
                                Text(isGoogleLoading ? "Signing in..." : "Sign in with Google")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color(.secondarySystemGroupedBackground))
                            .foregroundColor(.primary)
                            .cornerRadius(14)
                        }
                        .disabled(isGoogleLoading || isLoading)
                    }
                    .padding(.horizontal, 24)

                    Spacer(minLength: 40)
                }
            }

            // Full screen loading overlay while checking session
            if authVM.isLoading {
                Color(.systemBackground)
                    .ignoresSafeArea()
                    .overlay(
                        ProgressView()
                            .scaleEffect(1.5)
                    )
            }
        }
        .onAppear { focusedField = .email }
    }

    private var canSubmit: Bool {
        !email.isEmpty && !password.isEmpty && email.contains("@")
    }

    private func signIn() async {
        focusedField = nil
        isLoading = true
        errorMessage = nil
        do {
            try await authVM.login(email: email, password: password)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func signInWithGoogle() async {
        focusedField = nil
        isGoogleLoading = true
        errorMessage = nil

        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = scene.windows.first?.rootViewController else {
            errorMessage = "Cannot present Google sign-in. Please try again."
            isGoogleLoading = false
            return
        }

        do {
            try await authVM.loginWithGoogle(presentingViewController: rootVC)
        } catch {
            errorMessage = error.localizedDescription
        }
        isGoogleLoading = false
    }
}

// MARK: - Color Hex Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthViewModel())
}
