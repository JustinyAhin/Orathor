import Darwin
import Foundation

@MainActor
protocol PhononWorkerControlling: AnyObject {
    var onPartial: ((UUID, String) -> Void)? { get set }
    var onFailure: ((TranscriptionFailure) -> Void)? { get set }
    func prepare(configuration: PhononConfiguration) async throws
    func start(session: UUID) async throws
    func feed(_ audio: Data, session: UUID) async throws
    func finish(session: UUID) async throws -> String
    func shutdown()
}

nonisolated private struct PhononRequest: Encodable, Sendable {
    let id: UUID
    let op: String
    var session: UUID?
    var audio: String?
}

nonisolated private struct PhononResponse: Decodable, Sendable {
    let type: String
    var id: UUID?
    var session: UUID?
    var ok: Bool?
    var text: String?
    var error: String?
    var `protocol`: Int?
}

/// Blocking pipe writes live on an actor, never on the UI or microphone thread.
private actor PhononInputWriter {
    let handle: FileHandle
    init(handle: FileHandle) { self.handle = handle }
    func write(_ data: Data) throws { try handle.write(contentsOf: data) }
}

@MainActor
final class PhononWorker: PhononWorkerControlling {
    var onPartial: ((UUID, String) -> Void)?
    var onFailure: ((TranscriptionFailure) -> Void)?
    private var process: Process?
    private var output: FileHandle?
    private var input: FileHandle?
    private var log: FileHandle?
    private var writer: PhononInputWriter?
    private var pending: [UUID: CheckedContinuation<PhononResponse, Error>] = [:]
    private var timeouts: [UUID: Task<Void, Never>] = [:]
    private var lineBuffer = Data()
    private var generation = UUID()
    private var preparationID: UUID?
    private var preparationTask: Task<Void, Error>?
    private(set) var isReady = false
    var processIdentifier: Int32? {
        guard let process, process.isRunning else { return nil }
        return process.processIdentifier
    }

    func prepare(configuration: PhononConfiguration) async throws {
        if isReady, process?.isRunning == true { return }
        if let preparationTask { return try await preparationTask.value }
        shutdown()
        let token = UUID()
        preparationID = token
        let task = Task { [weak self] in
            guard let self else { throw CancellationError() }
            defer {
                if self.preparationID == token {
                    self.preparationTask = nil
                    self.preparationID = nil
                }
            }
            try self.launch(configuration)
            let launchGeneration = self.generation
            let reply = try await self.request("load", timeout: .seconds(90))
            guard launchGeneration == self.generation else { throw CancellationError() }
            guard reply.protocol == 1 else {
                let failure = TranscriptionFailure(
                    kind: .nonRecoverable,
                    message: "Phonon runtime version is incompatible. Download the engine again in Settings.")
                self.fail(failure)
                throw failure
            }
            self.isReady = true
            DiagnosticLogger.shared.log("Phonon: model loaded and warmed")
        }
        preparationTask = task
        try await task.value
    }

    func start(session: UUID) async throws { _ = try await request("start", session: session) }
    func feed(_ audio: Data, session: UUID) async throws {
        _ = try await request("audio", session: session, audio: audio.base64EncodedString())
    }
    func finish(session: UUID) async throws -> String {
        let reply = try await request("finish", session: session)
        return reply.text ?? ""
    }

    func shutdown() {
        generation = UUID()
        isReady = false
        preparationID = nil
        preparationTask?.cancel()
        preparationTask = nil
        output?.readabilityHandler = nil
        let activeProcess = process
        activeProcess?.terminationHandler = nil
        if activeProcess?.isRunning == true { activeProcess?.terminate() }
        close(input)
        close(output)
        close(log)
        process = nil
        input = nil
        output = nil
        log = nil
        writer = nil
        lineBuffer.removeAll(keepingCapacity: false)
        let waiting = Array(pending.values)
        pending.removeAll()
        for timeout in timeouts.values { timeout.cancel() }
        timeouts.removeAll()
        for continuation in waiting {
            continuation.resume(
                throwing: TranscriptionFailure(
                    kind: .transient, message: "Phonon stopped before finishing the transcript."))
        }
    }

    private func close(_ handle: FileHandle?) {
        do { try handle?.close() } catch {
            DiagnosticLogger.shared.log("Phonon pipe cleanup failed: \(error)")
        }
    }

    private func launch(_ configuration: PhononConfiguration) throws {
        let token = generation
        let process = Process()
        let stdin = Pipe()
        let stdout = Pipe()
        // A dead child must report an error, not deliver SIGPIPE to the app.
        _ = fcntl(stdin.fileHandleForWriting.fileDescriptor, F_SETNOSIGPIPE, 1)
        if !FileManager.default.fileExists(atPath: configuration.logURL.path) {
            FileManager.default.createFile(atPath: configuration.logURL.path, contents: nil)
        }
        let log = try FileHandle(forWritingTo: configuration.logURL)
        try log.truncate(atOffset: 0)
        process.executableURL = configuration.pythonURL
        process.arguments = ["-I", configuration.helperURL.path, "--model-dir", configuration.modelURL.path]
        process.environment = configuration.environment
        process.standardInput = stdin
        process.standardOutput = stdout
        process.standardError = log
        stdout.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            Task { @MainActor [weak self] in
                guard let self, self.generation == token else { return }
                if data.isEmpty {
                    self.fail(
                        TranscriptionFailure(
                            kind: .transient, message: "Phonon’s local engine stopped unexpectedly."))
                } else {
                    self.receive(data)
                }
            }
        }
        process.terminationHandler = { [weak self] finished in
            let status = finished.terminationStatus
            Task { @MainActor [weak self] in
                guard let self, self.generation == token else { return }
                self.fail(
                    TranscriptionFailure(
                        kind: .transient, message: "Phonon’s local engine exited (\(status))."))
            }
        }
        self.process = process
        self.input = stdin.fileHandleForWriting
        self.output = stdout.fileHandleForReading
        self.log = log
        writer = PhononInputWriter(handle: stdin.fileHandleForWriting)
        do {
            try process.run()
        } catch {
            shutdown()
            throw TranscriptionFailure(
                kind: .transient, message: "Phonon could not start: \(error.localizedDescription)")
        }
    }

    private func request(
        _ operation: String, session: UUID? = nil, audio: String? = nil,
        timeout: Duration = .seconds(30)
    ) async throws -> PhononResponse {
        guard let writer, process?.isRunning == true else {
            throw TranscriptionFailure(kind: .transient, message: "Phonon’s local engine is unavailable.")
        }
        let id = UUID()
        let token = generation
        var data = try JSONEncoder().encode(
            PhononRequest(id: id, op: operation, session: session, audio: audio))
        data.append(0x0A)
        return try await withCheckedThrowingContinuation { continuation in
            pending[id] = continuation
            timeouts[id] = Task { [weak self] in
                do { try await Task.sleep(for: timeout) } catch { return }
                guard let self, self.generation == token, self.pending[id] != nil else { return }
                self.fail(
                    TranscriptionFailure(
                        kind: .transient,
                        message:
                            "Phonon timed out while \(operation == "load" ? "loading the model" : "transcribing")."
                    ))
            }
            Task { [weak self] in
                do { try await writer.write(data) } catch {
                    guard let self, self.generation == token else { return }
                    self.fail(
                        TranscriptionFailure(
                            kind: .transient,
                            message: "Phonon could not receive the recording: \(error.localizedDescription)"))
                }
            }
        }
    }

    private func receive(_ data: Data) {
        lineBuffer.append(data)
        guard lineBuffer.count <= 1_048_576 else {
            fail(TranscriptionFailure(kind: .transient, message: "Phonon returned an oversized response."))
            return
        }
        while let newline = lineBuffer.firstIndex(of: 0x0A) {
            let line = lineBuffer.subdata(in: lineBuffer.startIndex..<newline)
            lineBuffer.removeSubrange(lineBuffer.startIndex...newline)
            do {
                let response = try JSONDecoder().decode(PhononResponse.self, from: line)
                if response.type == "partial", let session = response.session, let text = response.text {
                    onPartial?(session, text)
                } else if response.type == "reply", let id = response.id,
                    let continuation = pending.removeValue(forKey: id)
                {
                    timeouts.removeValue(forKey: id)?.cancel()
                    if response.ok == true {
                        continuation.resume(returning: response)
                    } else {
                        continuation.resume(
                            throwing: TranscriptionFailure(
                                kind: .transient,
                                message: response.error ?? "Phonon could not transcribe the recording."))
                    }
                }
            } catch {
                fail(TranscriptionFailure(kind: .transient, message: "Phonon returned an invalid response."))
                return
            }
        }
    }

    private func fail(_ failure: TranscriptionFailure) {
        shutdown()
        onFailure?(failure)
    }
}
