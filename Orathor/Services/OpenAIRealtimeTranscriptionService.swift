import AVFoundation
import Foundation

@Observable
final class OpenAIRealtimeTranscriptionService: NSObject, TranscriptionService,
  URLSessionWebSocketDelegate
{
  var transcribedText = ""
  var isTranscribing = false
  var onError: ((String) -> Void)?

  private let apiKey: String
  private let context: TranscriptionContext
  private let delay: String
  private var webSocketTask: URLSessionWebSocketTask?
  private var urlSession: URLSession?
  private var audioConverter: AVAudioConverter?
  private var targetFormat: AVAudioFormat?
  private var stopContinuation: CheckedContinuation<Void, Never>?
  private var stopTimeoutWorkItem: DispatchWorkItem?
  private var assembler = OpenAITranscriptAssembler()
  private let socketLock = NSLock()
  private var isSocketOpen = false
  private var pendingMessages: [URLSessionWebSocketTask.Message] = []
  private var connectStart: Date?
  private var didLogFirstTranscript = false
  private var keepAliveTask: Task<Void, Never>?
  private let warmIdleLimit: TimeInterval = 120

  init(
    apiKey: String, context: TranscriptionContext = TranscriptionContext(),
    delay: String = UserDefaults.standard.string(forKey: "whisperTranscriptionDelay") ?? "low"
  ) {
    self.apiKey = apiKey
    self.context = context
    self.delay = delay
  }

  func startTranscribing() async throws {
    guard !apiKey.isEmpty else { throw OpenAIRealtimeTranscriptionError.noAPIKey }
    guard !context.hasInvalidOpenAIKeywords else {
      throw OpenAIRealtimeTranscriptionError.invalidKeyword
    }

    transcribedText = ""
    assembler = OpenAITranscriptAssembler()
    didLogFirstTranscript = false
    keepAliveTask?.cancel()
    keepAliveTask = nil
    if isSocketWarm() {
      connectStart = Date()
      isTranscribing = true
      DiagnosticLogger.shared.log("OpenAI: reusing warm connection")
      return
    }
    try await connect()
  }

  func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
    if audioConverter == nil || audioConverter?.inputFormat != buffer.format {
      setupAudioConverter(sourceFormat: buffer.format)
    }
    guard let data = convertBufferToData(buffer) else { return }
    processAudioData(data)
  }

  func processAudioData(_ data: Data) {
    guard !data.isEmpty else { return }
    sendJSON(["type": "input_audio_buffer.append", "audio": data.base64EncodedString()])
  }

  func stopTranscribing() async {
    guard isTranscribing else { return }
    sendJSON(["type": "input_audio_buffer.commit"])
    await withCheckedContinuation { continuation in
      stopContinuation = continuation
      let timeout = DispatchWorkItem { [weak self] in
        DiagnosticLogger.shared.log("Stop timed out waiting for final transcript — tail may be cut")
        self?.resolveStop()
      }
      stopTimeoutWorkItem = timeout
      DispatchQueue.main.asyncAfter(deadline: .now() + 10, execute: timeout)
    }
    isTranscribing = false
    startKeepAlive()
  }

  func shutdown() {
    isTranscribing = false
    disconnect()
  }

  private func resolveStop() {
    stopTimeoutWorkItem?.cancel()
    stopTimeoutWorkItem = nil
    stopContinuation?.resume()
    stopContinuation = nil
  }

  private func connect() async throws {
    guard let url = URL(string: "wss://api.openai.com/v1/realtime?intent=transcription") else {
      throw OpenAIRealtimeTranscriptionError.invalidURL
    }
    var request = URLRequest(url: url)
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
    let task = session.webSocketTask(with: request)
    connectStart = Date()
    socketLock.lock()
    isSocketOpen = false
    urlSession = session
    webSocketTask = task
    socketLock.unlock()
    task.resume()
    isTranscribing = true
    listenForMessages(on: task)
  }

  private func disconnect() {
    keepAliveTask?.cancel()
    keepAliveTask = nil
    socketLock.lock()
    let task = webSocketTask
    let session = urlSession
    isSocketOpen = false
    pendingMessages = []
    webSocketTask = nil
    urlSession = nil
    socketLock.unlock()
    task?.cancel(with: .normalClosure, reason: nil)
    session?.invalidateAndCancel()
  }

  private func isSocketWarm() -> Bool {
    socketLock.lock()
    defer { socketLock.unlock() }
    return isSocketOpen && webSocketTask != nil
  }

  private func startKeepAlive() {
    keepAliveTask?.cancel()
    keepAliveTask = Task { @MainActor [weak self] in
      let idleStart = Date()
      while !Task.isCancelled {
        try? await Task.sleep(for: .seconds(15))
        guard let self, !Task.isCancelled else { return }
        guard Date().timeIntervalSince(idleStart) < warmIdleLimit else {
          self.disconnect()
          return
        }
        guard let task = self.currentWebSocketTask() else { return }
        task.sendPing { [weak self, weak task] error in
          guard error != nil, let self else { return }
          guard let task else { return }
          Task { @MainActor in self.handleDisconnect(for: task) }
        }
      }
    }
  }

  private func handleDisconnect(for task: URLSessionWebSocketTask) {
    guard markSocketClosedIfActive(task) else { return }
    guard isTranscribing else {
      disconnect()
      return
    }
    isTranscribing = false
    disconnect()
    resolveStop()
    onError?("Connection to OpenAI lost. Transcription may be incomplete.")
  }

  private func listenForMessages(on task: URLSessionWebSocketTask) {
    task.receive { [weak self, weak task] result in
      guard let self, let task, self.isActive(task) else { return }
      switch result {
      case .success(let message):
        if case .string(let text) = message { self.handleMessage(text, from: task) }
        self.listenForMessages(on: task)
      case .failure:
        Task { @MainActor in self.handleDisconnect(for: task) }
      }
    }
  }

  private func handleMessage(_ text: String, from task: URLSessionWebSocketTask) {
    guard let data = text.data(using: .utf8),
      let event = try? JSONDecoder().decode(OpenAIRealtimeEvent.self, from: data)
    else { return }
    Task { @MainActor in
      guard self.isActive(task) else { return }
      switch event.type {
      case "conversation.item.input_audio_transcription.delta":
        guard let delta = event.delta, !delta.isEmpty else { return }
        if !self.didLogFirstTranscript, let start = self.connectStart {
          self.didLogFirstTranscript = true
          DiagnosticLogger.shared.log(
            "OpenAI: first transcript \(Int(Date().timeIntervalSince(start) * 1000))ms after connect"
          )
        }
        self.transcribedText = self.assembler.applyingDelta(delta, itemID: event.itemID)
      case "conversation.item.input_audio_transcription.completed":
        self.transcribedText = self.assembler.applyingCompleted(
          event.transcript, itemID: event.itemID)
        self.resolveStop()
      case "error": self.handleErrorEvent(event)
      default: break
      }
    }
  }

  private func handleErrorEvent(_ event: OpenAIRealtimeEvent) {
    if event.error?.code == "input_audio_buffer_commit_empty" {
      resolveStop()
      return
    }
    let message = OpenAIRealtimeTranscriptionError.formattedMessage(
      code: event.error?.code, message: event.error?.message)
    isTranscribing = false
    disconnect()
    resolveStop()
    onError?(message)
  }

  private func setupAudioConverter(sourceFormat: AVAudioFormat) {
    guard
      let target = AVAudioFormat(
        commonFormat: .pcmFormatInt16, sampleRate: 24_000, channels: 1, interleaved: true)
    else { return }
    targetFormat = target
    audioConverter = AVAudioConverter(from: sourceFormat, to: target)
  }

  private func convertBufferToData(_ buffer: AVAudioPCMBuffer) -> Data? {
    guard let converter = audioConverter, let targetFormat else { return nil }
    let outputFrameCount = AVAudioFrameCount(
      Double(buffer.frameLength) * targetFormat.sampleRate / buffer.format.sampleRate)
    guard outputFrameCount > 0,
      let outputBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: outputFrameCount)
    else { return nil }
    var error: NSError?
    var hasData = false
    converter.convert(to: outputBuffer, error: &error) { _, status in
      guard !hasData else {
        status.pointee = .noDataNow
        return nil
      }
      hasData = true
      status.pointee = .haveData
      return buffer
    }
    guard error == nil, let samples = outputBuffer.int16ChannelData else { return nil }
    return Data(bytes: samples[0], count: Int(outputBuffer.frameLength) * 2)
  }

  private func sendJSON(_ dictionary: [String: Any]) {
    guard let message = jsonMessage(dictionary) else { return }
    enqueueOrSend(message)
  }
  private func jsonMessage(_ dictionary: [String: Any]) -> URLSessionWebSocketTask.Message? {
    guard let data = try? JSONSerialization.data(withJSONObject: dictionary),
      let text = String(data: data, encoding: .utf8)
    else { return nil }
    return .string(text)
  }
  private func enqueueOrSend(_ message: URLSessionWebSocketTask.Message) {
    socketLock.lock()
    defer { socketLock.unlock() }
    if isSocketOpen, let task = webSocketTask {
      send(message, on: task)
    } else {
      pendingMessages.append(message)
    }
  }
  private func send(_ message: URLSessionWebSocketTask.Message, on task: URLSessionWebSocketTask) {
    task.send(message) { [weak self, weak task] error in
      guard error != nil else { return }
      guard let task else { return }
      Task { @MainActor in self?.handleDisconnect(for: task) }
    }
  }

  func urlSession(
    _: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol _: String?
  ) {
    socketLock.lock()
    guard webSocketTask === self.webSocketTask else {
      socketLock.unlock()
      return
    }
    isSocketOpen = true
    if let update = jsonMessage(Self.sessionUpdatePayload(context: context, delay: delay)) {
      send(update, on: webSocketTask)
    }
    let queued = pendingMessages
    pendingMessages = []
    queued.forEach { send($0, on: webSocketTask) }
    socketLock.unlock()
  }
  func urlSession(
    _: URLSession, webSocketTask: URLSessionWebSocketTask,
    didCloseWith _: URLSessionWebSocketTask.CloseCode, reason _: Data?
  ) { Task { @MainActor in handleDisconnect(for: webSocketTask) } }

  private func currentWebSocketTask() -> URLSessionWebSocketTask? {
    socketLock.lock()
    defer { socketLock.unlock() }
    return webSocketTask
  }

  private func isActive(_ task: URLSessionWebSocketTask) -> Bool {
    socketLock.lock()
    defer { socketLock.unlock() }
    return task === webSocketTask
  }

  private func markSocketClosedIfActive(_ task: URLSessionWebSocketTask) -> Bool {
    socketLock.lock()
    defer { socketLock.unlock() }
    guard task === webSocketTask else { return false }
    isSocketOpen = false
    return true
  }

  static func sessionUpdatePayload(context: TranscriptionContext, delay: String) -> [String: Any] {
    var transcription: [String: Any] = ["model": "gpt-live-transcribe", "delay": delay]
    switch context.languages {
    case .automatic: break
    case .expected(let languages): transcription["languages"] = languages
    }
    if let prompt = context.prompt { transcription["prompt"] = prompt }
    if !context.keywords.isEmpty { transcription["keywords"] = context.keywords }
    return [
      "type": "session.update",
      "session": [
        "type": "transcription",
        "audio": [
          "input": [
            "format": ["type": "audio/pcm", "rate": 24_000], "transcription": transcription,
            "turn_detection": NSNull(),
          ]
        ],
      ],
    ]
  }

  enum OpenAIRealtimeTranscriptionError: LocalizedError {
    case invalidURL, noAPIKey, invalidKeyword
    var errorDescription: String? {
      switch self {
      case .invalidURL: "Failed to create OpenAI connection URL."
      case .noAPIKey: "OpenAI API key is required."
      case .invalidKeyword: "OpenAI keywords cannot contain angle brackets or line breaks."
      }
    }
    static func formattedMessage(code: String?, message: String?) -> String {
      let message = message?.trimmingCharacters(in: .whitespacesAndNewlines)
      if let code, !code.isEmpty, let message, !message.isEmpty {
        return "OpenAI error (\(code)): \(message)"
      }
      if let message, !message.isEmpty { return "OpenAI transcription failed: \(message)" }
      if let code, !code.isEmpty { return "OpenAI transcription failed (\(code))." }
      return "OpenAI transcription failed."
    }
  }
}

struct OpenAITranscriptAssembler {
  private var finalTextByItemID: [String: String] = [:]
  private var itemOrder: [String] = []
  private var activeDeltaItemID: String?
  private var activeDeltaText = ""

  mutating func applyingDelta(_ delta: String, itemID: String?) -> String {
    let itemID = itemID ?? activeDeltaItemID ?? "active"
    if activeDeltaItemID != itemID {
      activeDeltaItemID = itemID
      activeDeltaText = ""
    }
    appendItem(itemID)
    activeDeltaText += delta
    return assembledText
  }
  mutating func applyingCompleted(_ transcript: String?, itemID: String?) -> String {
    guard let transcript else { return assembledText }
    let itemID = itemID ?? activeDeltaItemID ?? UUID().uuidString
    appendItem(itemID)
    finalTextByItemID[itemID] = transcript
    if activeDeltaItemID == itemID || itemID == "active" {
      activeDeltaItemID = nil
      activeDeltaText = ""
    }
    return assembledText
  }
  private mutating func appendItem(_ itemID: String) {
    if !itemOrder.contains(itemID) { itemOrder.append(itemID) }
  }
  private var assembledText: String {
    (itemOrder.compactMap { finalTextByItemID[$0] }.filter { !$0.isEmpty }
      + (activeDeltaText.isEmpty ? [] : [activeDeltaText])).joined(separator: " ")
  }
}

private struct OpenAIRealtimeEvent: Decodable {
  let type: String
  let itemID: String?
  let delta: String?
  let transcript: String?
  let error: OpenAIRealtimeError?
  enum CodingKeys: String, CodingKey {
    case type
    case itemID = "item_id"
    case delta, transcript, error
  }
}
private struct OpenAIRealtimeError: Decodable {
  let message: String?
  let code: String?
}
