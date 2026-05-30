import SwiftUI

/// Fallback import path: user pastes raw LinkedIn profile HTML captured from
/// Safari (Share → Copy Page Source or a browser extension).
/// On success it calls back with the same EnrichmentResult as the WebView path.
struct LinkedInPasteView: View {
    var onEnrich: (EnrichmentResult) -> Void
    var onCancel: () -> Void

    @State private var pastedHTML = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let enrichmentService = EnrichmentService.shared
    private let indigo = Color(red: 0.31, green: 0.27, blue: 0.90)

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Inline error banner
                if let error = errorMessage {
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
                        Text("Open LinkedIn in Safari, navigate to the profile, tap Share → Copy Page Source (or use a browser extension), then paste it here.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Section("Page source") {
                        ZStack(alignment: .topLeading) {
                            if pastedHTML.isEmpty {
                                Text("Paste HTML here…")
                                    .foregroundColor(Color(.placeholderText))
                                    .padding(.top, 8)
                                    .padding(.leading, 4)
                                    .allowsHitTesting(false)
                            }
                            TextEditor(text: $pastedHTML)
                                .font(.system(.caption, design: .monospaced))
                                .frame(minHeight: 200)
                                .autocapitalization(.none)
                                .autocorrectionDisabled()
                        }
                    }

                    Section {
                        Button {
                            Task { await parseAndEnrich() }
                        } label: {
                            HStack {
                                Spacer()
                                if isLoading {
                                    ProgressView()
                                        .scaleEffect(0.9)
                                        .tint(.white)
                                } else {
                                    Label("Parse contact", systemImage: "person.crop.circle.badge.plus")
                                        .fontWeight(.semibold)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                        .disabled(pastedHTML.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
                        .listRowBackground(
                            indigo.opacity(pastedHTML.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
                        )
                        .foregroundColor(.white)
                    }
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle("Paste page source")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
            }
        }
    }

    // MARK: - Actions

    private func parseAndEnrich() async {
        let html = pastedHTML.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !html.isEmpty else { return }

        isLoading = true
        errorMessage = nil

        do {
            // Pass empty string for url — the server extracts it from the HTML.
            let result = try await enrichmentService.enrich(linkedinURL: "", html: html)
            onEnrich(result)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
