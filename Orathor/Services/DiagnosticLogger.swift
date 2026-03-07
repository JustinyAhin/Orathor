import AppKit
import Foundation
import os

final class DiagnosticLogger {
    static let shared = DiagnosticLogger()

    private let fileURL: URL
    private let queue = DispatchQueue(label: "segbedji.Orathor.diagnostics", qos: .utility)
    private let maxFileSize = 512 * 1024 // 512 KB — auto-rotates when exceeded

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("segbedji.Orathor", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("diagnostics.log")
    }

    func log(_ message: String, function: String = #function, file: String = #file) {
        let timestamp = ISO8601DateFormatter.shared.string(from: Date())
        let source = URL(fileURLWithPath: file).deletingPathExtension().lastPathComponent
        let line = "[\(timestamp)] [\(source).\(function)] \(message)\n"

        queue.async { [self] in
            rotateIfNeeded()
            if let data = line.data(using: .utf8) {
                if FileManager.default.fileExists(atPath: fileURL.path) {
                    if let handle = try? FileHandle(forWritingTo: fileURL) {
                        handle.seekToEndOfFile()
                        handle.write(data)
                        handle.closeFile()
                    }
                } else {
                    try? data.write(to: fileURL)
                }
            }
        }
    }

    func contents() -> String {
        queue.sync {
            (try? String(contentsOf: fileURL, encoding: .utf8)) ?? "(no diagnostic logs)"
        }
    }

    func copyToPasteboard() {
        let text = contents()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    func logFileURL() -> URL { fileURL }

    func clear() {
        queue.async { [self] in
            try? FileManager.default.removeItem(at: fileURL)
        }
    }

    // MARK: - Private

    private func rotateIfNeeded() {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
              let size = attrs[.size] as? Int, size > maxFileSize else { return }

        // Keep the last half of the file
        if let data = try? Data(contentsOf: fileURL),
           let text = String(data: data, encoding: .utf8) {
            let lines = text.components(separatedBy: "\n")
            let kept = lines.suffix(lines.count / 2).joined(separator: "\n")
            try? kept.data(using: .utf8)?.write(to: fileURL)
        }
    }
}

private extension ISO8601DateFormatter {
    static let shared: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
}
