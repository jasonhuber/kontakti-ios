import SwiftUI
import WebKit

struct LinkedInImportView: View {
    var onDismiss: (() -> Void)?

    @Environment(\.dismiss) private var dismiss

    // Step 1 — URL entry
    @State private var linkedinURL = ""
    @FocusState private var urlFieldFocused: Bool

    // Step 1b — WKWebView sheet to capture profile HTML
    @State private var showWebView = false
    @State private var pendingNormalizedURL = ""

    // Step 1c — paste fallback sheet
    @State private var showPasteView = false

    // Step 2 — pre-filled form
    @State private var enrichedResult: EnrichmentResult?

    // Loading / error
    @State private var isEnriching = false
    @State private var enrichError: String?
    @State private var isSaving = false
    @State private var saveError: String?

    // Form fields (populated after enrichment)
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var title = ""
    @State private var companyName = ""
    @State private var linkedinUrlField = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var notes = ""

    private let indigo = Color(red: 0.31, green: 0.27, blue: 0.90)
    private let api = APIClient.shared
    private let enrichmentService = EnrichmentService.shared

    var body: some View {
        NavigationStack {
            Group {
                if enrichedResult == nil {
                    urlEntryView
                } else {
                    addPersonForm
                }
            }
            .navigationTitle(enrichedResult == nil ? "Import from LinkedIn" : "Add Person")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                        onDismiss?()
                    }
                }
            }
        }
        .sheet(isPresented: $showWebView) {
            LinkedInWebViewSheet(
                linkedinURL: pendingNormalizedURL,
                onCapture: { html in
                    showWebView = false
                    Task { await runEnrichmentWithHTML(html, linkedinURL: pendingNormalizedURL) }
                },
                onCancel: {
                    showWebView = false
                }
            )
        }
        .sheet(isPresented: $showPasteView) {
            LinkedInPasteView(
                onEnrich: { result in
                    showPasteView = false
                    populateForm(from: result)
                    enrichedResult = result
                },
                onCancel: {
                    showPasteView = false
                }
            )
        }
    }

    // MARK: - URL Entry Step

    private var urlEntryView: some View {
        VStack(spacing: 0) {
            // Error banner
            if let error = enrichError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .background(Color.red)
            }

            Form {
                Section {
                    LinkedInProfileField(value: $linkedinURL, focus: $urlFieldFocused)
                } header: {
                    Text("LinkedIn Profile")
                } footer: {
                    Text("Type the profile slug. Full LinkedIn URLs also work.")
                        .font(.caption)
                }

                Section {
                    Button {
                        Task { await runEnrichment() }
                    } label: {
                        HStack {
                            Spacer()
                            if isEnriching {
                                ProgressView()
                                    .scaleEffect(0.9)
                                    .tint(.white)
                            } else {
                                Label("Enrich", systemImage: "link.badge.plus")
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                    .disabled(LinkedInProfileURL.normalized(from: linkedinURL) == nil || isEnriching)
                    .listRowBackground(
                        indigo.opacity(LinkedInProfileURL.normalized(from: linkedinURL) == nil ? 0.5 : 1)
                    )
                    .foregroundColor(.white)
                }

                Section {
                    Button {
                        showPasteView = true
                    } label: {
                        HStack {
                            Spacer()
                            Label("Paste HTML manually", systemImage: "doc.on.clipboard")
                                .font(.subheadline)
                            Spacer()
                        }
                        .padding(.vertical, 2)
                    }
                    .foregroundColor(indigo)
                } footer: {
                    Text("Use this if LinkedIn shows a login wall or captcha in the web view.")
                        .font(.caption)
                }
            }
            .listStyle(.insetGrouped)
        }
        .onAppear {
            urlFieldFocused = true
        }
    }

    // MARK: - Add Person Form

    private var addPersonForm: some View {
        VStack(spacing: 0) {
            // Source note banner
            if enrichedResult?.source == "url_only" {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.caption)
                    Text("LinkedIn blocked the fetch. Only the URL was saved — fill in details manually.")
                        .font(.caption)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(Color.orange)
            }

            // Save error banner
            if let error = saveError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .background(Color.red)
            }

            Form {
                Section("Name") {
                    TextField("First name", text: $firstName)
                    TextField("Last name", text: $lastName)
                }

                Section("Work") {
                    TextField("Title", text: $title)
                    TextField("Company", text: $companyName)
                }

                Section("Contact") {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                    TextField("Phone", text: $phone)
                        .textContentType(.telephoneNumber)
                        .keyboardType(.phonePad)
                }

                Section("LinkedIn") {
                    LinkedInProfileField(value: $linkedinUrlField)
                }

                Section("Notes") {
                    ZStack(alignment: .topLeading) {
                        if notes.isEmpty {
                            Text("Any additional notes…")
                                .foregroundColor(Color(.placeholderText))
                                .padding(.top, 8)
                                .padding(.leading, 4)
                        }
                        TextEditor(text: $notes)
                            .frame(minHeight: 80)
                    }
                }

                Section {
                    Button {
                        Task { await savePerson() }
                    } label: {
                        HStack {
                            Spacer()
                            if isSaving {
                                ProgressView()
                                    .scaleEffect(0.9)
                                    .tint(.white)
                            } else {
                                Text("Add to Kontakti")
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                    .disabled(firstName.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                    .listRowBackground(
                        indigo.opacity(firstName.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
                    )
                    .foregroundColor(.white)
                }
            }
            .listStyle(.insetGrouped)
        }
    }

    // MARK: - Actions

    /// Tap "Enrich" → open a WKWebView so LinkedIn sees a real browser session.
    /// The web view captures the profile HTML and calls back to runEnrichmentWithHTML.
    private func runEnrichment() async {
        guard let normalizedURL = LinkedInProfileURL.normalized(from: linkedinURL) else { return }
        linkedinURL = LinkedInProfileURL.displayValue(from: normalizedURL)
        pendingNormalizedURL = normalizedURL
        enrichError = nil
        showWebView = true
    }

    /// Called by the web view sheet once it has extracted the page HTML.
    private func runEnrichmentWithHTML(_ html: String, linkedinURL: String) async {
        isEnriching = true
        enrichError = nil

        do {
            let result = try await enrichmentService.enrich(linkedinURL: linkedinURL, html: html)
            populateForm(from: result)
            enrichedResult = result
        } catch {
            enrichError = error.localizedDescription
        }

        isEnriching = false
    }

    private func populateForm(from result: EnrichmentResult) {
        let p = result.person
        firstName = p.firstName ?? ""
        lastName = p.lastName ?? ""
        title = p.title ?? ""
        companyName = p.company?.name ?? ""
        linkedinUrlField = LinkedInProfileURL.displayValue(from: p.linkedinUrl ?? linkedinURL)
        email = p.email ?? ""
        phone = p.phone ?? ""

        // Build notes from headline + summary if present
        var noteParts: [String] = []
        if let headline = p.metadata?.headline, !headline.isEmpty {
            noteParts.append(headline)
        }
        if let summary = p.metadata?.summary, !summary.isEmpty {
            noteParts.append(summary)
        }
        notes = noteParts.joined(separator: "\n\n")
    }

    private func savePerson() async {
        let trimmedFirst = firstName.trimmingCharacters(in: .whitespaces)
        guard !trimmedFirst.isEmpty else { return }

        isSaving = true
        saveError = nil

        let req = CreatePersonRequest(
            firstName: trimmedFirst,
            lastName: lastName.trimmingCharacters(in: .whitespaces).nilIfEmpty,
            email: email.trimmingCharacters(in: .whitespaces).nilIfEmpty,
            phone: phone.trimmingCharacters(in: .whitespaces).nilIfEmpty,
            linkedinUrl: LinkedInProfileURL.normalized(from: linkedinUrlField),
            avatarUrl: enrichedResult?.person.avatarUrl,
            title: title.trimmingCharacters(in: .whitespaces).nilIfEmpty,
            companyName: companyName.trimmingCharacters(in: .whitespaces).nilIfEmpty,
            notes: notes.trimmingCharacters(in: .whitespaces).nilIfEmpty
        )

        do {
            let person = try await api.createPerson(req)
            OfflineStore.shared.upsertPeople([person])
            dismiss()
            onDismiss?()
        } catch {
            saveError = error.localizedDescription
        }

        isSaving = false
    }
}

// MARK: - WKWebView Sheet

/// A full-screen sheet that loads a LinkedIn profile in WKWebView.
/// Once the profile page finishes loading (detected by URL containing /in/),
/// it extracts document.body.outerHTML and calls onCapture.
/// The user can log in to LinkedIn here if not already authenticated —
/// WKWebView persists cookies so subsequent opens are instant.
struct LinkedInWebViewSheet: View {
    let linkedinURL: String
    var onCapture: (String) -> Void
    var onCancel: () -> Void

    @State private var statusMessage = "Loading LinkedIn profile…"
    @State private var showingLoginHint = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                LinkedInWebViewRepresentable(
                    urlString: linkedinURL,
                    onHTMLCaptured: onCapture,
                    onLoginRequired: {
                        showingLoginHint = true
                    }
                )
                .ignoresSafeArea()

                if showingLoginHint {
                    HStack(spacing: 8) {
                        Image(systemName: "lock.fill")
                        Text("Sign in to LinkedIn, then the profile will load automatically.")
                            .font(.caption)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 16)
                    .background(Color.indigo)
                }
            }
            .navigationTitle("LinkedIn")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
            }
        }
    }
}

// MARK: - WKWebView UIViewRepresentable

struct LinkedInWebViewRepresentable: UIViewRepresentable {
    let urlString: String
    var onHTMLCaptured: (String) -> Void
    var onLoginRequired: () -> Void

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        // Use persistent data store so LinkedIn session cookie survives app restarts
        config.websiteDataStore = .default()

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"

        if let url = URL(string: urlString) {
            webView.load(URLRequest(url: url))
        }
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onHTMLCaptured: onHTMLCaptured, onLoginRequired: onLoginRequired)
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var onHTMLCaptured: (String) -> Void
        var onLoginRequired: () -> Void
        private var hasCaptured = false

        init(onHTMLCaptured: @escaping (String) -> Void, onLoginRequired: @escaping () -> Void) {
            self.onHTMLCaptured = onHTMLCaptured
            self.onLoginRequired = onLoginRequired
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard !hasCaptured else { return }
            guard let currentURL = webView.url?.absoluteString else { return }

            // Detect auth wall / login page → tell the user to sign in
            let isAuthWall = currentURL.contains("authwall")
                || currentURL.contains("/login")
                || currentURL.contains("/checkpoint")
                || currentURL.contains("uas/login")
            if isAuthWall {
                DispatchQueue.main.async { self.onLoginRequired() }
                return
            }

            // Only extract HTML from a real /in/ profile page
            guard currentURL.contains("/in/") else { return }

            hasCaptured = true
            webView.evaluateJavaScript("document.documentElement.outerHTML") { result, error in
                guard let html = result as? String, !html.isEmpty else { return }
                DispatchQueue.main.async { self.onHTMLCaptured(html) }
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            // Navigation errors are silently ignored; user can retry or cancel
        }
    }
}

// MARK: - LinkedInProfileField

private struct LinkedInProfileField: View {
    @Binding var value: String
    var focus: FocusState<Bool>.Binding?

    var body: some View {
        HStack(spacing: 0) {
            Text("linkedin.com/in/")
                .foregroundStyle(.secondary)
            textField
        }
    }

    @ViewBuilder
    private var textField: some View {
        let field = TextField("someone", text: $value)
            .textContentType(.URL)
            .keyboardType(.URL)
            .autocapitalization(.none)
            .autocorrectionDisabled()
            .onChange(of: value) { _, newValue in
                let displayValue = LinkedInProfileURL.displayValue(from: newValue)
                if displayValue != newValue {
                    value = displayValue
                }
            }

        if let focus {
            field.focused(focus)
        } else {
            field
        }
    }
}

// MARK: - LinkedInProfileURL

private enum LinkedInProfileURL {
    static func normalized(from rawValue: String) -> String? {
        let slug = displayValue(from: rawValue)
        guard !slug.isEmpty else { return nil }

        let allowed = CharacterSet.urlPathAllowed.subtracting(CharacterSet(charactersIn: "/"))
        guard let encodedSlug = slug.addingPercentEncoding(withAllowedCharacters: allowed) else {
            return nil
        }

        return "https://www.linkedin.com/in/\(encodedSlug)"
    }

    static func displayValue(from rawValue: String) -> String {
        var value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !value.isEmpty else { return "" }

        value = value.replacingOccurrences(of: " ", with: "")

        if let url = url(from: value),
           let host = url.host?.lowercased(),
           host.contains("linkedin.com") {
            let parts = url.path
                .split(separator: "/")
                .map(String.init)

            if parts.first?.lowercased() == "in", parts.count > 1 {
                return cleanSlug(parts[1])
            }

            if let firstPart = parts.first {
                return cleanSlug(firstPart)
            }
        }

        for prefix in [
            "https://www.linkedin.com/in/",
            "http://www.linkedin.com/in/",
            "https://linkedin.com/in/",
            "http://linkedin.com/in/",
            "www.linkedin.com/in/",
            "linkedin.com/in/",
            "/in/",
            "in/",
            "https://www.linkedin.com/",
            "http://www.linkedin.com/",
            "https://linkedin.com/",
            "http://linkedin.com/",
            "www.linkedin.com/",
            "linkedin.com/",
        ] {
            if value.lowercased().hasPrefix(prefix) {
                value.removeFirst(prefix.count)
                break
            }
        }

        if let delimiterIndex = value.firstIndex(where: { $0 == "?" || $0 == "#" || $0 == "/" }) {
            value = String(value[..<delimiterIndex])
        }

        return cleanSlug(value)
    }

    private static func url(from value: String) -> URL? {
        if let url = URL(string: value), url.scheme != nil {
            return url
        }
        return URL(string: "https://\(value)")
    }

    private static func cleanSlug(_ value: String) -> String {
        value
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

private extension Color {
    static let indigo = Color(red: 0.31, green: 0.27, blue: 0.90)
}
