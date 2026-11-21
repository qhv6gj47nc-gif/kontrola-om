import SwiftUI
import WebKit

@main
struct KontrolaOMApp: App {
    var body: some Scene {
        WindowGroup {
            WebView()
                .ignoresSafeArea(.container, edges: .bottom)
                .background(Color(red: 0.114, green: 0.31, blue: 0.451))
        }
    }
}

/// Zobrazí přibalenou aplikaci (Web/index.html) – funguje plně offline,
/// historie kontrol se ukládá do úložiště v telefonu.
struct WebView: UIViewRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()          // trvalé localStorage
        config.userContentController.add(context.coordinator, name: "share")
        let web = WKWebView(frame: .zero, configuration: config)
        web.isOpaque = false
        web.backgroundColor = .clear
        web.scrollView.contentInsetAdjustmentBehavior = .never
        web.navigationDelegate = context.coordinator
        if let url = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "Web") {
            web.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
        return web
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        // Externí odkazy (PDF připojovacích podmínek) otevřít v Safari
        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if let url = action.request.url, url.scheme == "https" || url.scheme == "http" {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }

        // Nativní sdílení protokolu (WhatsApp, e-mail, Poznámky…)
        func userContentController(_ uc: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let text = message.body as? String else { return }
            let vc = UIActivityViewController(activityItems: [text], applicationActivities: nil)
            guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let root = scene.windows.first?.rootViewController else { return }
            vc.popoverPresentationController?.sourceView = root.view
            root.present(vc, animated: true)
        }
    }
}
