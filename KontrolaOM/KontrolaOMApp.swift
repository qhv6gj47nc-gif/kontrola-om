import SwiftUI
import WebKit
import UIKit

@main
struct KontrolaOMApp: App {
    var body: some Scene {
        WindowGroup {
            WebView()
                .ignoresSafeArea(.container, edges: .bottom)
                .background(Color(UIColor.systemGroupedBackground))
        }
    }
}

/// Zobrazí přibalenou aplikaci (Web/index.html) – kontrola funguje plně offline,
/// historie kontrol se ukládá do úložiště v telefonu. Rozbor fotky potřebuje internet.
struct WebView: UIViewRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()          // trvalé localStorage
        for name in ["share", "setKey", "hasKey", "photo"] {
            config.userContentController.add(context.coordinator, name: name)
        }
        let web = WKWebView(frame: .zero, configuration: config)
        web.isOpaque = false
        web.backgroundColor = .clear
        web.scrollView.contentInsetAdjustmentBehavior = .never
        web.navigationDelegate = context.coordinator
        context.coordinator.webView = web
        if let url = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "Web") {
            web.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
        return web
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler,
                             UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        weak var webView: WKWebView?
        private var pendingRequest: [String: Any]?

        private var rootVC: UIViewController? {
            let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene
            var vc = scene?.windows.first(where: { $0.isKeyWindow })?.rootViewController
                ?? scene?.windows.first?.rootViewController
            while let presented = vc?.presentedViewController { vc = presented }
            return vc
        }

        /// Zavolá funkci v JS s JSON argumentem (bezpečně zakódovaným).
        private func callJS(_ fn: String, _ value: Any) {
            guard let data = try? JSONSerialization.data(withJSONObject: [value]),
                  let arr = String(data: data, encoding: .utf8) else { return }
            DispatchQueue.main.async {
                self.webView?.evaluateJavaScript("window.\(fn) && window.\(fn).apply(null, \(arr))")
            }
        }

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

        func userContentController(_ uc: WKUserContentController, didReceive message: WKScriptMessage) {
            switch message.name {
            case "share":
                guard let text = message.body as? String, let root = rootVC else { return }
                let vc = UIActivityViewController(activityItems: [text], applicationActivities: nil)
                vc.popoverPresentationController?.sourceView = root.view
                root.present(vc, animated: true)

            case "setKey":
                KeyStore.save((message.body as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines))
                callJS("onKeyState", KeyStore.load() != nil)

            case "hasKey":
                callJS("onKeyState", KeyStore.load() != nil)

            case "photo":
                guard let body = message.body as? [String: Any],
                      let request = body["request"] as? [String: Any], let root = rootVC else { return }
                pendingRequest = request
                let picker = UIImagePickerController()
                let wantsCamera = (body["source"] as? String) != "library"
                picker.sourceType = wantsCamera && UIImagePickerController.isSourceTypeAvailable(.camera)
                    ? .camera : .photoLibrary
                picker.delegate = self
                root.present(picker, animated: true)

            default: break
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
            callJS("onPhotoCancel", true)
        }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            picker.dismiss(animated: true)
            guard let image = info[.originalImage] as? UIImage, let request = pendingRequest else {
                callJS("onPhotoError", "Fotku se nepodařilo načíst.")
                return
            }
            if let thumb = PhotoAnalyzer.jpegBase64(image) { callJS("onPhotoTaken", thumb) }
            Task {
                do {
                    let json = try await PhotoAnalyzer.analyze(images: [image], request: request)
                    callJS("onPhotoResult", json)
                } catch {
                    callJS("onPhotoError", error.localizedDescription)
                }
            }
        }
    }
}
