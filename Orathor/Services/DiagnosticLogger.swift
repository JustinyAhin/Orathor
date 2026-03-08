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
        let text = shareableReport()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    /// Builds a trimmed diagnostic report: current session info header + last 200 log lines.
    func shareableReport(tailLineCount: Int = 200) -> String {
        let full = contents()
        let allLines = full.components(separatedBy: "\n")

        // Find the last session header block
        var sessionHeader: [String] = []
        if let lastSessionIdx = allLines.lastIndex(where: { $0.contains("--- Session Start ---") }) {
            // Grab from "--- Session Start ---" through "---------------------"
            for i in lastSessionIdx..<allLines.count {
                sessionHeader.append(allLines[i])
                if allLines[i].contains("---------------------") { break }
            }
        }

        // Tail the log
        let tail = allLines.suffix(tailLineCount)

        // If the session header is already within the tail, just return the tail
        if let firstSessionLine = sessionHeader.first, tail.contains(where: { $0 == firstSessionLine }) {
            return tail.joined(separator: "\n")
        }

        // Otherwise prepend the session header
        var report = sessionHeader
        if !sessionHeader.isEmpty {
            report.append("") // blank separator
            report.append("... (\(allLines.count - tailLineCount) earlier lines omitted)")
            report.append("")
        }
        report.append(contentsOf: tail)
        return report.joined(separator: "\n")
    }

    func logFileURL() -> URL { fileURL }

    func logSessionStart() {
        let bundle = Bundle.main
        let appVersion = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let buildNumber = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        let osVersion = ProcessInfo.processInfo.operatingSystemVersion
        let osString = "macOS \(osVersion.majorVersion).\(osVersion.minorVersion).\(osVersion.patchVersion)"

        var hw = "unknown"
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        if size > 0 {
            var model = [CChar](repeating: 0, count: size)
            sysctlbyname("hw.model", &model, &size, nil, 0)
            hw = String(cString: model)
        }

        let defaults = UserDefaults.standard
        let engine = defaults.string(forKey: "speechEngine") ?? "apple"
        let insertKey = defaults.string(forKey: "insertHotkey") ?? "rightOption"
        let clipboardKey = defaults.string(forKey: "clipboardHotkey") ?? "none"
        let dock = (defaults.object(forKey: "showInDock") as? Bool ?? false) ? "yes" : "no"

        let lines = [
            "--- Session Start ---",
            "App: \(appVersion) (\(buildNumber))",
            "OS: \(osString)",
            "Hardware: \(hw)",
            "Engine: \(engine)",
            "Insert hotkey: \(insertKey)",
            "Clipboard hotkey: \(clipboardKey)",
            "Show in dock: \(dock)",
            "---------------------",
        ]
        for line in lines { log(line) }
    }

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
