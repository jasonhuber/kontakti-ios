import UIKit
import Social
import MobileCoreServices
import UniformTypeIdentifiers

/// Receives an Instagram / Facebook / X / TikTok URL from the iOS share sheet,
/// extracts platform + handle, then opens the main Kontakti app via
/// `kontakti://link-social?platform=…&handle=…`.
final class ShareViewController: SLComposeServiceViewController {

    private var detectedURL: URL?

    override func isContentValid() -> Bool {
        return detectedURL != nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Link to Kontakti"
        placeholder = "Optional note (ignored)"
        extractURL()
    }

    override func didSelectPost() {
        guard let url = detectedURL, let payload = makeKontaktiURL(from: url) else {
            cancelWithUnsupportedURL()
            return
        }
        openMainApp(payload)
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }

    override func configurationItems() -> [Any]! {
        return []
    }

    // MARK: - URL extraction

    private func extractURL() {
        guard let item = extensionContext?.inputItems.first as? NSExtensionItem else {
            return
        }
        let providers = item.attachments ?? []
        let urlType = UTType.url.identifier
        let textType = UTType.plainText.identifier

        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(urlType) {
                provider.loadItem(forTypeIdentifier: urlType, options: nil) { [weak self] item, _ in
                    if let url = item as? URL {
                        DispatchQueue.main.async {
                            self?.detectedURL = url
                            self?.validateContent()
                        }
                    } else if let str = item as? String, let url = URL(string: str) {
                        DispatchQueue.main.async {
                            self?.detectedURL = url
                            self?.validateContent()
                        }
                    }
                }
                return
            }
            if provider.hasItemConformingToTypeIdentifier(textType) {
                provider.loadItem(forTypeIdentifier: textType, options: nil) { [weak self] item, _ in
                    if let str = item as? String,
                       let match = Self.firstURL(in: str) {
                        DispatchQueue.main.async {
                            self?.detectedURL = match
                            self?.validateContent()
                        }
                    }
                }
                return
            }
        }
    }

    private static func firstURL(in text: String) -> URL? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let range = NSRange(text.startIndex..., in: text)
        if let match = detector?.firstMatch(in: text, range: range),
           let urlRange = Range(match.range, in: text) {
            return URL(string: String(text[urlRange]))
        }
        return nil
    }

    // MARK: - Build kontakti:// URL

    private func makeKontaktiURL(from url: URL) -> URL? {
        let host = url.host?.lowercased() ?? ""
        let path = url.path

        var comps = URLComponents()
        comps.scheme = "kontakti"
        comps.host = "link-social"

        if host.contains("instagram.com") {
            let handle = path.split(separator: "/").first.map(String.init)
            guard let h = handle, !h.isEmpty else { return nil }
            comps.queryItems = [
                URLQueryItem(name: "platform", value: "instagram"),
                URLQueryItem(name: "handle", value: h.replacingOccurrences(of: "@", with: ""))
            ]
            return comps.url
        }
        if host.contains("facebook.com") || host.contains("fb.com") {
            comps.queryItems = [
                URLQueryItem(name: "platform", value: "facebook"),
                URLQueryItem(name: "url", value: url.absoluteString)
            ]
            return comps.url
        }
        if host.contains("twitter.com") || host == "x.com" || host.hasSuffix(".x.com") {
            let handle = path.split(separator: "/").first.map(String.init)
            guard let h = handle, !h.isEmpty else { return nil }
            comps.queryItems = [
                URLQueryItem(name: "platform", value: "twitter"),
                URLQueryItem(name: "handle", value: h.replacingOccurrences(of: "@", with: ""))
            ]
            return comps.url
        }
        if host.contains("tiktok.com") {
            // Path like /@username
            let segments = path.split(separator: "/").map(String.init)
            let raw = segments.first(where: { $0.hasPrefix("@") }) ?? segments.first ?? ""
            let h = raw.replacingOccurrences(of: "@", with: "")
            guard !h.isEmpty else { return nil }
            comps.queryItems = [
                URLQueryItem(name: "platform", value: "tiktok"),
                URLQueryItem(name: "handle", value: h)
            ]
            return comps.url
        }
        return nil
    }

    // MARK: - Open main app

    /// Share extensions can't directly call UIApplication.shared.open. The standard trick
    /// is to walk up the responder chain to find a UIApplication and invoke openURL: via
    /// selector — this works on iOS 17.
    private func openMainApp(_ url: URL) {
        var responder: UIResponder? = self
        while let r = responder {
            if let app = r as? UIApplication {
                let sel = NSSelectorFromString("openURL:")
                if app.responds(to: sel) {
                    _ = app.perform(sel, with: url)
                    return
                }
            }
            responder = r.next
        }
    }

    private func cancelWithUnsupportedURL() {
        extensionContext?.cancelRequest(withError: NSError(
            domain: "com.jasonhuber.KontaktiShare",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Unsupported URL — share a profile from Instagram, Facebook, X, or TikTok."]
        ))
    }
}
