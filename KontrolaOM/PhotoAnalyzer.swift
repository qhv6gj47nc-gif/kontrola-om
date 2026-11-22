import UIKit
import Security

/// Uložení API klíče Anthropic do Keychainu (nikdy ne do localStorage).
enum KeyStore {
    private static let service = "cz.monter.kontrolaom.anthropic"

    static func save(_ key: String) {
        let base: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                   kSecAttrService as String: service]
        SecItemDelete(base as CFDictionary)
        guard !key.isEmpty else { return }
        var add = base
        add[kSecValueData as String] = Data(key.utf8)
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(add as CFDictionary, nil)
    }

    static func load() -> String? {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                kSecAttrService as String: service,
                                kSecReturnData as String: true,
                                kSecMatchLimit as String: kSecMatchLimitOne]
        var out: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess,
              let data = out as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

/// Odešle fotku rozváděče do Claude API a vrátí JSON s rozpoznanými údaji.
/// Text promptu a JSON schéma sestavuje webová část aplikace (index.html),
/// Swift jen přidá fotku, klíč a odešle požadavek.
enum PhotoAnalyzer {
    enum Failure: LocalizedError {
        case noKey, badImage, http(Int, String), refusal, empty
        var errorDescription: String? {
            switch self {
            case .noKey: return "Chybí API klíč. Zadejte ho v Nastavení rozpoznávání."
            case .badImage: return "Fotku se nepodařilo zpracovat."
            case .http(let code, let msg): return "Chyba služby (\(code)): \(msg)"
            case .refusal: return "Rozbor fotky byl odmítnut. Zkuste jinou fotku."
            case .empty: return "Služba nevrátila žádný výsledek."
            }
        }
    }

    /// Zmenší fotku na max. 1568 px na delší straně (víc model stejně nevyužije).
    static func jpegBase64(_ image: UIImage, maxSide: CGFloat = 1568) -> String? {
        let scale = min(1, maxSide / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: size)
        let resized = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
        return resized.jpegData(compressionQuality: 0.8)?.base64EncodedString()
    }

    /// - Parameters:
    ///   - photos: dvojice (popisek, fotka); popisek se pošle jako text před fotkou
    ///   - request: objekt z webové části: { system, text, schema, labels }
    static func analyze(photos: [(label: String, image: UIImage)], request: [String: Any]) async throws -> String {
        guard let key = KeyStore.load(), !key.isEmpty else { throw Failure.noKey }
        var content: [[String: Any]] = []
        for (label, img) in photos {
            guard let b64 = jpegBase64(img) else { throw Failure.badImage }
            content.append(["type": "text", "text": label])
            content.append(["type": "image",
                            "source": ["type": "base64", "media_type": "image/jpeg", "data": b64]])
        }
        content.append(["type": "text", "text": request["text"] as? String ?? ""])

        let body: [String: Any] = [
            "model": "claude-opus-5-5",
            "max_tokens": 16000,
            "system": request["system"] as? String ?? "",
            "fallbacks": "default",
            "output_config": [
                "effort": "medium",
                "format": ["type": "json_schema", "schema": request["schema"] ?? [:]]
            ],
            "messages": [["role": "user", "content": content]]
        ]

        var req = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        req.httpMethod = "POST"
        req.timeoutInterval = 180
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(key, forHTTPHeaderField: "x-api-key")
        req.setValue("2026-10-21", forHTTPHeaderField: "anthropic-version")
        req.setValue("server-side-fallback-2026-07-01", forHTTPHeaderField: "anthropic-beta")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, resp) = try await URLSession.shared.data(for: req)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        guard code == 200 else {
            let msg = (json["error"] as? [String: Any])?["message"] as? String ?? "neznámá chyba"
            throw Failure.http(code, msg)
        }
        if json["stop_reason"] as? String == "refusal" { throw Failure.refusal }
        let blocks = json["content"] as? [[String: Any]] ?? []
        guard let text = blocks.first(where: { $0["type"] as? String == "text" })?["text"] as? String,
              !text.isEmpty else { throw Failure.empty }
        return text
    }
}
