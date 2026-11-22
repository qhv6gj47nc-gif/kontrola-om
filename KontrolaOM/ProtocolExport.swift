import UIKit
import CoreText

/// Ukládání fotek a protokolů do složky aplikace (viditelná v aplikaci Soubory
/// a v iTunes na PC) a vytvoření PDF protokolu s fotkami.
enum ProtocolExport {
    static var documents: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    /// Fotky rozpracované kontroly (smažou se při „Nová kontrola“).
    static var currentPhotosDir: URL {
        let url = documents.appendingPathComponent("Rozpracovaná kontrola", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
    static var protocolsDir: URL {
        let url = documents.appendingPathComponent("Protokoly", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func savePhoto(_ image: UIImage) {
        let n = ((try? FileManager.default.contentsOfDirectory(atPath: currentPhotosDir.path))?.count ?? 0) + 1
        let url = currentPhotosDir.appendingPathComponent(String(format: "foto-%02d.jpg", n))
        if let data = image.jpegData(compressionQuality: 0.85) { try? data.write(to: url) }
    }

    static func currentPhotos() -> [URL] {
        let files = (try? FileManager.default.contentsOfDirectory(at: currentPhotosDir,
                                                                  includingPropertiesForKeys: nil)) ?? []
        return files.filter { $0.pathExtension.lowercased() == "jpg" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    static func clearCurrent() {
        for url in currentPhotos() { try? FileManager.default.removeItem(at: url) }
    }

    static func safeName(_ s: String) -> String {
        let bad = CharacterSet(charactersIn: "/\\:?%*|\"<>\n\r\t")
        let cleaned = s.components(separatedBy: bad).joined(separator: "-")
            .trimmingCharacters(in: .whitespaces)
        return cleaned.isEmpty ? "Kontrola" : String(cleaned.prefix(80))
    }

    /// Vytvoří složku Protokoly/<název>/ s PDF protokolem a kopiemi fotek. Vrací URL složky a PDF.
    static func export(text: String, name: String) throws -> (folder: URL, pdf: URL) {
        let folder = protocolsDir.appendingPathComponent(safeName(name), isDirectory: true)
        try? FileManager.default.removeItem(at: folder)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let photos = currentPhotos()
        for p in photos {
            try? FileManager.default.copyItem(at: p, to: folder.appendingPathComponent(p.lastPathComponent))
        }
        try text.write(to: folder.appendingPathComponent("protokol.txt"), atomically: true, encoding: .utf8)

        let pdfURL = folder.appendingPathComponent(safeName(name) + ".pdf")
        let page = CGRect(x: 0, y: 0, width: 595, height: 842)          // A4 v bodech
        let margin: CGFloat = 40
        let renderer = UIGraphicsPDFRenderer(bounds: page)
        try renderer.writePDF(to: pdfURL) { ctx in
            // Text protokolu, stránkovaný
            let style = NSMutableParagraphStyle(); style.lineSpacing = 3
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 11), .paragraphStyle: style, .foregroundColor: UIColor.black]
            let lines = text.components(separatedBy: "\n")
            let title = lines.first ?? ""
            let body = NSAttributedString(string: lines.dropFirst().joined(separator: "\n"), attributes: attrs)
            let framesetter = CTFramesetterCreateWithAttributedString(body as CFAttributedString)
            var start = 0
            var first = true
            repeat {
                ctx.beginPage()
                var top = margin
                if first {
                    (title as NSString).draw(at: CGPoint(x: margin, y: top),
                                             withAttributes: [.font: UIFont.boldSystemFont(ofSize: 16)])
                    top += 30
                    first = false
                }
                let rect = CGRect(x: margin, y: top, width: page.width - 2 * margin, height: page.height - top - margin)
                let path = CGPath(rect: CGRect(x: rect.minX, y: page.height - rect.maxY,
                                               width: rect.width, height: rect.height), transform: nil)
                let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: start, length: 0), path, nil)
                let cg = ctx.cgContext
                cg.saveGState()
                cg.textMatrix = .identity
                cg.translateBy(x: 0, y: page.height); cg.scaleBy(x: 1, y: -1)
                CTFrameDraw(frame, cg)
                cg.restoreGState()
                let visible = CTFrameGetVisibleStringRange(frame)
                start += visible.length
                if visible.length == 0 { break }
            } while start < body.length

            // Fotky, jedna na stránku
            for (i, url) in photos.enumerated() {
                guard let img = UIImage(contentsOfFile: url.path) else { continue }
                ctx.beginPage()
                ("Fotka \(i + 1)" as NSString).draw(at: CGPoint(x: margin, y: margin),
                                                    withAttributes: [.font: UIFont.boldSystemFont(ofSize: 13)])
                let box = CGRect(x: margin, y: margin + 26, width: page.width - 2 * margin,
                                 height: page.height - 2 * margin - 26)
                let s = min(box.width / img.size.width, box.height / img.size.height)
                let size = CGSize(width: img.size.width * s, height: img.size.height * s)
                img.draw(in: CGRect(x: box.midX - size.width / 2, y: box.minY, width: size.width, height: size.height))
            }
        }
        return (folder, pdfURL)
    }
}
