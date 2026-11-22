import SwiftUI
import WebKit
import UIKit

@main
struct KontrolaOMApp: App {
    var body: some Scene {
        WindowGroup {
            WebView()
                .ignoresSafeArea(.container, edges: .bottom)
                .background(Color(red: 0.949, green: 0.31, blue: 0.0))
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
        for name in ["share", "setKey", "hasKey", "photo", "newCheck", "listPhotos", "analyze"] {
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
        private var pendingSlot = 1

        private var rootVC: UIViewController? {
            let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene
            var vc = scene?.windows.first(where: { $0.isKeyWindow })?.rootViewController
                ?? scene?.windows.first?.rootViewController
            while let presented = vc?.presentedViewController { vc = presented }
            return vc
        }

        /// Zavolá funkci v JS s JSON argumentem (bezpečně zakódovaným).
        private func callJS(_ fn: String, _ values: Any...) {
            guard let data = try? JSONSerialization.data(withJSONObject: values),
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
                guard let root = rootVC else { return }
                var items: [Any] = []
                if let body = message.body as? [String: Any], let text = body["text"] as? String {
                    let name = body["name"] as? String ?? "Kontrola"
                    if let out = try? ProtocolExport.export(text: text, name: name) {
                        items = [out.pdf]
                        callJS("onExported", "Protokoly/" + out.folder.lastPathComponent)
                    } else { items = [text] }
                } else if let text = message.body as? String { items = [text] }
                let vc = UIActivityViewController(activityItems: items, applicationActivities: nil)
                vc.popoverPresentationController?.sourceView = root.view
                root.present(vc, animated: true)

            case "newCheck":
                ProtocolExport.clearCurrent()

            case "setKey":
                KeyStore.save((message.body as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines))
                callJS("onKeyState", KeyStore.load() != nil)

            case "hasKey":
                callJS("onKeyState", KeyStore.load() != nil)

            case "listPhotos":
                var thumbs: [String: String] = [:]
                for (slot, url) in ProtocolExport.slotPhotos() {
                    if let img = UIImage(contentsOfFile: url.path),
                       let t = PhotoAnalyzer.jpegBase64(img, maxSide: 360) { thumbs[String(slot)] = t }
                }
                callJS("onPhotoSlots", thumbs)

            case "analyze":
                guard let body = message.body as? [String: Any],
                      let request = body["request"] as? [String: Any] else { return }
                let labels = request["labels"] as? [String] ?? []
                let photos = ProtocolExport.slotPhotos().compactMap { slot, url -> (label: String, image: UIImage)? in
                    guard let img = UIImage(contentsOfFile: url.path) else { return nil }
                    let label = slot - 1 < labels.count ? labels[slot - 1] : "Fotka \(slot)"
                    return (label: label, image: img)
                }
                Task {
                    do {
                        let json = try await PhotoAnalyzer.analyze(photos: photos, request: request)
                        callJS("onPhotoResult", json)
                    } catch {
                        callJS("onPhotoError", error.localizedDescription)
                    }
                }

            case "photo":
                guard let body = message.body as? [String: Any], let root = rootVC else { return }
                pendingSlot = body["slot"] as? Int ?? 1
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
            guard let image = info[.originalImage] as? UIImage else {
                callJS("onPhotoError", "Fotku se nepodařilo načíst.")
                return
            }
            ProtocolExport.savePhoto(image, slot: pendingSlot)
            callJS("onPhotoTaken", pendingSlot, PhotoAnalyzer.jpegBase64(image, maxSide: 360) ?? "")
        }
    }
}
