import CryptoKit
import Foundation
import os

nonisolated struct PhononConfiguration: Sendable {
    let pythonURL: URL
    let helperURL: URL
    let modelURL: URL
    let environment: [String: String]
    let logURL: URL
}

/// Only the optional engine installs here; it never uses a system Python or
/// changes the user's shell, package manager, preferences, or global caches.
@MainActor
@Observable
final class PhononRuntime {
    static let shared = PhononRuntime()
    static let runtimeVersion = "phonon-2-0.2.3-v1"
    private static let uvVersion = "0.12.21"
    private static let uvSHA256 = "b88bda573e566ef9bced66b155fe0408626fbbc053aee1c30ba686f0728c9447"

    private(set) var isInstalled: Bool
    private(set) var isInstalling = false
    private(set) var installationMessage = ""
    private(set) var errorMessage: String?
    @ObservationIgnored private var installationTask: Task<Void, Never>?
    let rootURL: URL

    // No actor-bound teardown is needed. Avoid the isolated-deinit runtime
    // crash in synchronous XCTest scopes (swiftlang/swift#87316).
    nonisolated deinit {}

    static var isSupported: Bool {
        #if arch(arm64)
            true
        #else
            false
        #endif
    }

    init(rootURL: URL? = nil) {
        self.rootURL =
            rootURL
            ?? FileManager.default.urls(
                for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "segbedji.Orathor/Phonon", directoryHint: .isDirectory)
        isInstalled = Self.hasInstallation(at: self.rootURL)
    }

    private var versionURL: URL { rootURL.appending(path: Self.runtimeVersion) }
    private var pythonURL: URL { versionURL.appending(path: "venv/bin/python") }
    private var modelURL: URL {
        rootURL.appending(path: "models/speech/FermionResearch__Phonon-2/model_phonon2_c4c_int6")
    }
    private var markerURL: URL { versionURL.appending(path: "installed.txt") }

    private static func hasInstallation(at root: URL) -> Bool {
        let version = root.appending(path: runtimeVersion)
        let manager = FileManager.default
        guard let marker = try? String(contentsOf: version.appending(path: "installed.txt"), encoding: .utf8),
            marker == runtimeVersion,
            manager.isExecutableFile(atPath: version.appending(path: "venv/bin/python").path)
        else { return false }
        let model = root.appending(path: "models/speech/FermionResearch__Phonon-2/model_phonon2_c4c_int6")
        return ["model.fermion", "config.json", "packed_manifest.json"].allSatisfy {
            manager.fileExists(atPath: model.appending(path: $0).path)
        }
    }

    func configuration() throws -> PhononConfiguration {
        guard Self.isSupported else {
            throw TranscriptionFailure(
                kind: .nonRecoverable, message: "Phonon 2 requires an Apple silicon Mac.")
        }
        guard isInstalled, Self.hasInstallation(at: rootURL) else {
            isInstalled = false
            throw TranscriptionFailure(
                kind: .nonRecoverable, message: "Download Phonon 2 in Settings before dictating with it.")
        }
        return PhononConfiguration(
            pythonURL: pythonURL,
            helperURL: try Self.resource("phonon_worker", extension: "py"),
            modelURL: modelURL,
            environment: environment(offline: true),
            logURL: rootURL.appending(path: "worker.log")
        )
    }

    static func resource(_ name: String, extension suffix: String) throws -> URL {
        guard let url = Bundle.main.url(forResource: name, withExtension: suffix) else {
            throw TranscriptionFailure(
                kind: .nonRecoverable, message: "Phonon setup files are missing. Reinstall Orathor.")
        }
        return url
    }

    func install(onInstalled: @escaping @MainActor () -> Void = {}) {
        guard !isInstalling, Self.isSupported else { return }
        isInstalling = true
        errorMessage = nil
        installationTask = Task { [weak self] in
            guard let self else { return }
            defer {
                self.isInstalling = false
                self.installationTask = nil
            }
            do {
                try await self.performInstallation()
                try Task.checkCancellation()
                self.isInstalled = true
                self.installationMessage = "Installed · English only"
                onInstalled()
            } catch is CancellationError {
                self.installationMessage = "Download cancelled"
            } catch {
                self.errorMessage = error.localizedDescription
                self.installationMessage = "Setup failed. You can retry the download."
                DiagnosticLogger.shared.log("Phonon setup failed: \(error)")
            }
        }
    }

    func cancelInstallation() { installationTask?.cancel() }
    func clearError() { errorMessage = nil }

    private func environment(offline: Bool) -> [String: String] {
        let inherited = ProcessInfo.processInfo.environment
        var environment = inherited.filter { ["HOME", "TMPDIR", "LANG", "LC_ALL"].contains($0.key) }
        environment["PATH"] = "/usr/bin:/bin:/usr/sbin:/sbin"
        environment["PYTHONUNBUFFERED"] = "1"
        environment["PYTHONNOUSERSITE"] = "1"
        environment["FERMION_CACHE_DIR"] = rootURL.appending(path: "models").path
        environment["FERMION_DEVICE"] = "mlx"
        environment["FERMION_P2_FAST"] = "tdt16,dense16"
        environment["HF_HOME"] = rootURL.appending(path: "downloads").path
        environment["HF_HUB_DISABLE_TELEMETRY"] = "1"
        environment["HF_HUB_OFFLINE"] = offline ? "1" : "0"
        environment["UV_PYTHON_INSTALL_DIR"] = rootURL.appending(path: "python").path
        environment["UV_CACHE_DIR"] = rootURL.appending(path: "package-cache").path
        environment["UV_NO_CONFIG"] = "1"
        return environment
    }

    private func performInstallation() async throws {
        let manager = FileManager.default
        try manager.createDirectory(at: versionURL, withIntermediateDirectories: true)
        // A failed retry cannot advertise an incomplete runtime as installed.
        if manager.fileExists(atPath: markerURL.path) { try manager.removeItem(at: markerURL) }
        isInstalled = false
        let uvDirectory = rootURL.appending(path: "tools/uv-\(Self.uvVersion)")
        let uvURL = uvDirectory.appending(path: "uv-aarch64-apple-darwin/uv")
        let setupLog = rootURL.appending(path: "setup.log")
        if !manager.isExecutableFile(atPath: uvURL.path) {
            installationMessage = "Downloading setup tools…"
            let archiveURL = uvDirectory.appending(path: "uv.tar.gz")
            try manager.createDirectory(at: uvDirectory, withIntermediateDirectories: true)
            guard
                let url = URL(
                    string:
                        "https://github.com/astral-sh/uv/releases/download/\(Self.uvVersion)/uv-aarch64-apple-darwin.tar.gz?download=1"
                )
            else {
                throw URLError(.badURL)
            }
            let (download, response) = try await downloadSetupTool(from: url)
            guard let response = response as? HTTPURLResponse, response.statusCode == 200 else {
                throw TranscriptionFailure(
                    kind: .nonRecoverable,
                    message: "Phonon setup tools could not be downloaded. Try again later.")
            }
            let checksum = try await Task.detached {
                SHA256.hash(data: try Data(contentsOf: download)).map { String(format: "%02x", $0) }.joined()
            }.value
            guard checksum == Self.uvSHA256 else {
                throw TranscriptionFailure(
                    kind: .nonRecoverable,
                    message: "Phonon setup tool verification failed. Try downloading again.")
            }
            if manager.fileExists(atPath: archiveURL.path) { try manager.removeItem(at: archiveURL) }
            try manager.moveItem(at: download, to: archiveURL)
            try await PhononSetupProcess.run(
                URL(filePath: "/usr/bin/tar"), arguments: ["-xzf", archiveURL.path, "-C", uvDirectory.path],
                environment: environment(offline: false), logURL: setupLog)
            try manager.removeItem(at: archiveURL)
        }
        try Task.checkCancellation()
        installationMessage = "Installing the local engine…"
        try await PhononSetupProcess.run(
            uvURL,
            arguments: [
                "venv", "--clear", "--managed-python", "--python", "3.13.12",
                versionURL.appending(path: "venv").path,
            ],
            environment: environment(offline: false), logURL: setupLog)
        let requirements = try Self.resource("phonon-requirements", extension: "txt")
        try await PhononSetupProcess.run(
            uvURL,
            arguments: [
                "pip", "install", "--python", pythonURL.path, "--require-hashes", "--only-binary", ":all:",
                "--index-url", "https://pypi.org/simple", "-r", requirements.path,
            ],
            environment: environment(offline: false), logURL: setupLog)
        installationMessage = "Downloading and verifying Phonon 2…"
        try await PhononSetupProcess.run(
            pythonURL,
            arguments: ["-I", try Self.resource("phonon_worker", extension: "py").path, "--download"],
            environment: environment(offline: false), logURL: setupLog)
        try Task.checkCancellation()
        try Self.runtimeVersion.write(to: markerURL, atomically: true, encoding: .utf8)
    }

    private func downloadSetupTool(from url: URL) async throws -> (URL, URLResponse) {
        for attempt in 0..<3 {
            try Task.checkCancellation()
            var request = URLRequest(
                url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 60)
            request.setValue("Orathor-Phonon-Setup", forHTTPHeaderField: "User-Agent")
            let result = try await URLSession.shared.download(for: request)
            let status = (result.1 as? HTTPURLResponse)?.statusCode ?? 0
            if !(500..<600).contains(status) || attempt == 2 { return result }
            try FileManager.default.removeItem(at: result.0)
            try await Task.sleep(for: .seconds(attempt + 1))
        }
        throw URLError(.cannotLoadFromNetwork)
    }
}

nonisolated private final class PhononSetupCancellation: Sendable {
    private struct State {
        var process: Process?
        var isCancelled = false
    }
    private let lock = OSAllocatedUnfairLock(initialState: State())
    func start(_ process: Process) throws {
        try lock.withLock { state in
            guard !state.isCancelled else { throw CancellationError() }
            state.process = process
            try process.run()
        }
    }
    func cancel() {
        lock.withLock { state in
            state.isCancelled = true
            if let process = state.process, process.isRunning { process.terminate() }
        }
    }
    func finish() -> Bool {
        lock.withLock { state in
            state.process = nil
            return state.isCancelled
        }
    }
}

nonisolated enum PhononSetupProcess {
    static func run(_ executable: URL, arguments: [String], environment: [String: String], logURL: URL)
        async throws
    {
        let cancellation = PhononSetupCancellation()
        try await withTaskCancellationHandler {
            try Task.checkCancellation()
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                do {
                    let manager = FileManager.default
                    if !manager.fileExists(atPath: logURL.path) {
                        manager.createFile(atPath: logURL.path, contents: nil)
                    }
                    let log = try FileHandle(forWritingTo: logURL)
                    try log.seekToEnd()
                    let process = Process()
                    process.executableURL = executable
                    process.arguments = arguments
                    process.environment = environment
                    process.standardOutput = log
                    process.standardError = log
                    process.terminationHandler = { finished in
                        finished.terminationHandler = nil
                        try? log.close()
                        if cancellation.finish() {
                            continuation.resume(throwing: CancellationError())
                        } else if finished.terminationStatus == 0 {
                            continuation.resume()
                        } else {
                            NSLog("Phonon setup process exited with status %d", finished.terminationStatus)
                            continuation.resume(
                                throwing: TranscriptionFailure(
                                    kind: .nonRecoverable,
                                    message: "Phonon setup didn’t finish. Retry the download in Settings."))
                        }
                    }
                    try cancellation.start(process)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        } onCancel: {
            cancellation.cancel()
        }
    }
}
