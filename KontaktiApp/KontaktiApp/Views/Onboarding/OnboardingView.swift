import SwiftUI

// MARK: - Main container

struct OnboardingView: View {
    @EnvironmentObject private var authVM: AuthViewModel

    @State private var step = 0
    @State private var phoneImported = 0
    @State private var googleImported = 0

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            stepContent
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal:   .move(edge: .leading).combined(with: .opacity)
                ))
                .id(step)
        }
        .animation(.easeInOut(duration: 0.35), value: step)
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case 0:
            WelcomeStep(
                onStart: { step = 1 },
                onSkip:  { authVM.completeOnboarding() }
            )
        case 1:
            PhoneStep(
                onDone: { n in phoneImported = n; step = 2 },
                onSkip: { step = 2 }
            )
        case 2:
            GoogleStep(
                onDone: { n in googleImported = n; step = 3 },
                onSkip: { step = 3 }
            )
        default:
            DoneStep(
                phoneCount:  phoneImported,
                googleCount: googleImported,
                onFinish: { authVM.completeOnboarding() }
            )
        }
    }
}

// MARK: - Welcome

private struct WelcomeStep: View {
    let onStart: () -> Void
    let onSkip:  () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 28) {
                ZStack {
                    RoundedRectangle(cornerRadius: 32)
                        .fill(Color(hex: "#4F46E5"))
                        .frame(width: 112, height: 112)
                    Text("K")
                        .font(.system(size: 60, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                VStack(spacing: 10) {
                    Text("Welcome to Kontakti")
                        .font(.largeTitle).fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    Text("Let's seed your network with real contacts\nso you're not starting from a blank page.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                }
            }
            .padding(.horizontal, 32)
            Spacer()
            VStack(spacing: 12) {
                Button("Get started", action: onStart)
                    .buttonStyle(OBPrimaryStyle())
                Button("Skip for now", action: onSkip)
                    .buttonStyle(OBSecondaryStyle())
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 52)
        }
    }
}

// MARK: - Phone contacts step

private struct PhoneStep: View {
    let onDone: (Int) -> Void
    let onSkip: () -> Void

    enum Phase { case loading, denied(String), ready([ImportCandidate]), done(Int) }

    @State private var phase: Phase = .loading
    @State private var isImporting = false
    @State private var importError: String?

    var body: some View {
        VStack(spacing: 0) {
            StepHeader(systemImage: "iphone", title: "Import from iPhone",
                       subtitle: "We'll scan your contacts for\npeople not yet in Kontakti.")

            Group {
                switch phase {
                case .loading:
                    SpinnerBody(label: "Scanning contacts…")

                case .denied(let msg):
                    ErrorBody(message: msg) {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }

                case .ready(let candidates):
                    if candidates.isEmpty {
                        EmptyBody(message: "All your iPhone contacts are already in Kontakti.")
                    } else {
                        CandidatePreview(candidates: candidates, error: importError)
                    }

                case .done(let n):
                    SuccessBody(count: n, source: "iPhone")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            footerButtons
                .padding(.horizontal, 24)
                .padding(.bottom, 52)
        }
        .task { await load() }
    }

    @ViewBuilder
    private var footerButtons: some View {
        VStack(spacing: 12) {
            if case .ready(let candidates) = phase, !candidates.isEmpty {
                Button {
                    Task { await doImport(candidates) }
                } label: {
                    if isImporting {
                        ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Import \(candidates.count) contacts")
                    }
                }
                .buttonStyle(OBPrimaryStyle())
                .disabled(isImporting)
            }
            if case .done(let n) = phase {
                Button("Next →") { onDone(n) }
                    .buttonStyle(OBPrimaryStyle())
            } else {
                Button("Skip") { onSkip() }
                    .buttonStyle(OBSecondaryStyle())
            }
        }
    }

    private func load() async {
        do {
            let c = try await ContactsImporter.shared.fetchNewCandidates()
            phase = .ready(c)
        } catch let e as ContactsImporterError {
            phase = .denied(e.localizedDescription)
        } catch {
            phase = .denied(error.localizedDescription)
        }
    }

    private func doImport(_ candidates: [ImportCandidate]) async {
        isImporting = true
        importError = nil
        do {
            let normalized = candidates.compactMap { $0.normalizedForImport() }
            guard !normalized.isEmpty else {
                importError = "None of the selected contacts include enough information to import."
                isImporting = false
                return
            }

            let result = try await APIClient.shared.importContacts(BulkImportRequest(contacts: normalized))
            await OfflineStore.shared.upsertPeople(result.people)
            phase = .done(result.imported)
        } catch {
            importError = error.localizedDescription
        }
        isImporting = false
    }
}

// MARK: - Google contacts step

private struct GoogleStep: View {
    let onDone: (Int) -> Void
    let onSkip: () -> Void

    enum Phase { case idle, connecting, fetching, ready([ImportCandidate]), done(Int), failed(String) }

    @State private var phase: Phase = .idle
    @State private var isImporting = false
    @State private var importError: String?

    var body: some View {
        VStack(spacing: 0) {
            StepHeader(systemImage: "envelope.circle", title: "Import from Google",
                       subtitle: "Pull in Google Contacts and\nfrequent Gmail senders.")

            Group {
                switch phase {
                case .idle:
                    Spacer()
                case .connecting:
                    SpinnerBody(label: "Connecting to Google…")
                case .fetching:
                    SpinnerBody(label: "Fetching contacts…")
                case .ready(let candidates):
                    if candidates.isEmpty {
                        EmptyBody(message: "All your Google contacts are already in Kontakti.")
                    } else {
                        CandidatePreview(candidates: candidates, error: importError)
                    }
                case .done(let n):
                    SuccessBody(count: n, source: "Google")
                case .failed(let msg):
                    ErrorBody(message: msg, onAction: nil)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            footerButtons
                .padding(.horizontal, 24)
                .padding(.bottom, 52)
        }
        .task {
            // Reuse existing Google session from sign-in if available
            if let token = GoogleAuthService.shared.accessToken {
                await fetchCandidates(token)
            }
        }
    }

    @ViewBuilder
    private var footerButtons: some View {
        VStack(spacing: 12) {
            switch phase {
            case .idle, .failed:
                Button("Connect Google Contacts") { Task { await connect() } }
                    .buttonStyle(OBPrimaryStyle())
                Button("Skip") { onSkip() }
                    .buttonStyle(OBSecondaryStyle())
            case .ready(let candidates):
                if !candidates.isEmpty {
                    Button {
                        Task { await doImport(candidates) }
                    } label: {
                        if isImporting {
                            ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Import \(candidates.count) contacts")
                        }
                    }
                    .buttonStyle(OBPrimaryStyle())
                    .disabled(isImporting)
                }
                Button("Skip") { onSkip() }
                    .buttonStyle(OBSecondaryStyle())
            case .done(let n):
                Button("Next →") { onDone(n) }
                    .buttonStyle(OBPrimaryStyle())
            default:
                Button("Skip") { onSkip() }
                    .buttonStyle(OBSecondaryStyle())
            }
        }
    }

    private func connect() async {
        phase = .connecting
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = scene.windows.first?.rootViewController else {
            phase = .failed("Cannot present Google sign-in.")
            return
        }
        do {
            let token = try await GoogleAuthService.shared.signIn(presentingViewController: rootVC)
            await fetchCandidates(token)
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    private func fetchCandidates(_ accessToken: String) async {
        phase = .fetching
        do {
            let c = try await GmailContactsService.shared.fetchNewCandidates(accessToken: accessToken)
            phase = .ready(c)
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    private func doImport(_ candidates: [ImportCandidate]) async {
        isImporting = true
        importError = nil
        do {
            let normalized = candidates.compactMap { $0.normalizedForImport() }
            guard !normalized.isEmpty else {
                importError = "None of the selected contacts include enough information to import."
                isImporting = false
                return
            }

            let result = try await APIClient.shared.importContacts(BulkImportRequest(contacts: normalized))
            await OfflineStore.shared.upsertPeople(result.people)
            phase = .done(result.imported)
        } catch {
            importError = error.localizedDescription
        }
        isImporting = false
    }
}

// MARK: - Done step

private struct DoneStep: View {
    let phoneCount:  Int
    let googleCount: Int
    let onFinish: () -> Void

    private var total: Int { phoneCount + googleCount }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 28) {
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.12))
                        .frame(width: 112, height: 112)
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.green)
                }
                VStack(spacing: 10) {
                    Text("You're all set!")
                        .font(.largeTitle).fontWeight(.bold)
                    Text(total > 0
                         ? "\(total) contacts imported and ready to manage."
                         : "You can import contacts anytime from the People tab.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                if phoneCount > 0 || googleCount > 0 {
                    importSummary
                }
            }
            .padding(.horizontal, 32)
            Spacer()
            Button("Open Kontakti", action: onFinish)
                .buttonStyle(OBPrimaryStyle())
                .padding(.horizontal, 24)
                .padding(.bottom, 52)
        }
    }

    private var importSummary: some View {
        VStack(spacing: 0) {
            if phoneCount > 0 {
                summaryRow(icon: "iphone", label: "iPhone contacts",
                           color: Color(hex: "#4F46E5"), count: phoneCount)
            }
            if googleCount > 0 {
                if phoneCount > 0 { Divider().padding(.leading, 44) }
                summaryRow(icon: "envelope.circle", label: "Google contacts",
                           color: .red, count: googleCount)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .padding(.horizontal, 0)
    }

    private func summaryRow(icon: String, label: String, color: Color, count: Int) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)
            Text(label).font(.subheadline)
            Spacer()
            Text("\(count)")
                .font(.subheadline).fontWeight(.semibold)
                .foregroundColor(color)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Reusable sub-views

private struct StepHeader: View {
    let systemImage: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.system(size: 52))
                .foregroundColor(Color(hex: "#4F46E5"))
                .padding(.top, 60)
            VStack(spacing: 8) {
                Text(title).font(.title).fontWeight(.bold)
                Text(subtitle)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 28)
    }
}

private struct CandidatePreview: View {
    let candidates: [ImportCandidate]
    var error: String? = nil

    var body: some View {
        VStack(spacing: 12) {
            Text("\(candidates.count) contacts found")
                .font(.headline)
            if let err = error {
                Text(err).font(.caption).foregroundColor(.red).multilineTextAlignment(.center)
            }
            VStack(spacing: 0) {
                ForEach(Array(candidates.prefix(4))) { c in
                    HStack(spacing: 12) {
                        ZStack {
                            Circle().fill(Color(.systemGray5)).frame(width: 38, height: 38)
                            Text(initials(c))
                                .font(.footnote).fontWeight(.semibold)
                                .foregroundColor(Color(.systemGray))
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(c.firstName) \(c.lastName)".trimmingCharacters(in: .whitespaces))
                                .font(.subheadline)
                            if let email = c.email {
                                Text(email).font(.caption).foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    if c.id != candidates.prefix(4).last?.id {
                        Divider().padding(.leading, 66)
                    }
                }
                if candidates.count > 4 {
                    Text("+ \(candidates.count - 4) more")
                        .font(.caption).foregroundColor(.secondary)
                        .padding(.vertical, 10)
                }
            }
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
        .padding(.horizontal, 24)
        .padding(.top, 4)
    }

    private func initials(_ c: ImportCandidate) -> String {
        let f = c.firstName.first.map(String.init) ?? ""
        let l = c.lastName.first.map(String.init) ?? ""
        let s = (f + l).uppercased()
        return s.isEmpty ? "?" : s
    }
}

private struct SpinnerBody: View {
    let label: String
    var body: some View {
        VStack(spacing: 12) {
            ProgressView().scaleEffect(1.2)
            Text(label).font(.caption).foregroundColor(.secondary)
        }
    }
}

private struct SuccessBody: View {
    let count: Int
    let source: String
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 52)).foregroundColor(.green)
            Text("\(count) contacts imported from \(source)")
                .font(.title3).fontWeight(.semibold)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 32)
    }
}

private struct EmptyBody: View {
    let message: String
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 40)).foregroundColor(.secondary)
            Text(message)
                .font(.body).foregroundColor(.secondary)
                .multilineTextAlignment(.center).padding(.horizontal, 32)
        }
    }
}

private struct ErrorBody: View {
    let message: String
    var onAction: (() -> Void)?

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 40)).foregroundColor(.orange)
            Text(message)
                .font(.body).foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            if let action = onAction {
                Button("Open Settings", action: action)
                    .buttonStyle(OBPrimaryStyle())
                    .padding(.horizontal, 32)
            }
        }
        .padding(.horizontal, 32)
    }
}

// MARK: - Button styles

private struct OBPrimaryStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(configuration.isPressed ? Color(hex: "#4338CA") : Color(hex: "#4F46E5"))
            .foregroundColor(.white)
            .font(.body.weight(.semibold))
            .cornerRadius(14)
            .opacity(configuration.isPressed ? 0.9 : 1)
    }
}

private struct OBSecondaryStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .foregroundColor(.secondary)
            .font(.body)
    }
}
