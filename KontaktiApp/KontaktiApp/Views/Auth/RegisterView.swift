import SwiftUI

struct RegisterView: View {
    @EnvironmentObject private var authVM: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name      = ""
    @State private var username  = ""
    @State private var email     = ""
    @State private var password  = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @FocusState private var focused: Field?

    private enum Field { case name, username, email, password }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 32) {
                    Spacer(minLength: 40)

                    VStack(spacing: 4) {
                        Text("Create account")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        Text("Personal relationship intelligence")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    VStack(spacing: 12) {
                        field("Full name", text: $name, tag: .name,
                              next: .username, keyboard: .default, content: .name)

                        field("Username", text: $username, tag: .username,
                              next: .email, keyboard: .asciiCapable, content: .username,
                              transform: { $0.lowercased().filter { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" } })

                        field("Email", text: $email, tag: .email,
                              next: .password, keyboard: .emailAddress, content: .emailAddress)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Password")
                                .font(.footnote).fontWeight(.medium).foregroundColor(.secondary)
                            SecureField("8+ characters", text: $password)
                                .textContentType(.newPassword)
                                .focused($focused, equals: .password)
                                .submitLabel(.go)
                                .onSubmit { Task { await submit() } }
                                .padding(14)
                                .background(Color(.secondarySystemGroupedBackground))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(focused == .password ? Color(hex: "#4F46E5") : Color.clear, lineWidth: 2)
                                )
                        }

                        if let error = errorMessage {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.circle.fill").foregroundColor(.red)
                                Text(error).font(.footnote).foregroundColor(.red)
                                Spacer()
                            }
                            .padding(12)
                            .background(Color.red.opacity(0.08))
                            .cornerRadius(10)
                        }

                        Button {
                            Task { await submit() }
                        } label: {
                            HStack {
                                if isLoading {
                                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white)).scaleEffect(0.85)
                                } else {
                                    Text("Create account").fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity).frame(height: 50)
                            .background(canSubmit ? Color(hex: "#4F46E5") : Color(hex: "#4F46E5").opacity(0.5))
                            .foregroundColor(.white)
                            .cornerRadius(14)
                        }
                        .disabled(!canSubmit || isLoading)
                    }
                    .padding(.horizontal, 24)

                    Spacer(minLength: 40)
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { focused = .name }
    }

    // MARK: - Helpers

    private var canSubmit: Bool {
        !name.isEmpty && !username.isEmpty && email.contains("@") && password.count >= 8
    }

    private func submit() async {
        focused = nil
        isLoading = true
        errorMessage = nil
        do {
            try await authVM.register(name: name, username: username, email: email, password: password)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    @ViewBuilder
    private func field(
        _ label: String,
        text: Binding<String>,
        tag: Field,
        next: Field,
        keyboard: UIKeyboardType,
        content: UITextContentType,
        transform: ((String) -> String)? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.footnote).fontWeight(.medium).foregroundColor(.secondary)
            TextField(label, text: text)
                .keyboardType(keyboard)
                .textContentType(content)
                .autocapitalization(keyboard == .default && tag == .name ? .words : .none)
                .autocorrectionDisabled()
                .focused($focused, equals: tag)
                .submitLabel(.next)
                .onSubmit { focused = next }
                .onChange(of: text.wrappedValue) { _, new in
                    if let t = transform { text.wrappedValue = t(new) }
                }
                .padding(14)
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(focused == tag ? Color(hex: "#4F46E5") : Color.clear, lineWidth: 2)
                )
        }
    }
}

#Preview {
    NavigationStack {
        RegisterView()
            .environmentObject(AuthViewModel())
    }
}
