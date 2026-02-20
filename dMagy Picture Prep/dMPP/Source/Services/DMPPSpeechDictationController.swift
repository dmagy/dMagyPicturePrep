import Foundation
import Combine
import SwiftUI
import Speech
import AVFoundation

// ================================================================
// DMPPSpeechDictationController.swift
// cp-2026-02-20-02(DICTATION-CONTROLLER-CLEAN)
// - Uses Apple's Speech framework to transcribe microphone input
// - Writes into a provided Binding<String> during an active session
// - Keeps last transcript when stopping (does NOT clear description)
// - Throttles partial updates to reduce AppKit layout churn
// ================================================================

@MainActor
final class DMPPSpeechDictationController: ObservableObject {

    // MARK: - Published state (for UI)

    @Published private(set) var isRecording: Bool = false
    @Published private(set) var lastError: String? = nil

    /// Latest transcript (partial or final).
    /// This stays populated after stop (useful for debugging / UI).
    @Published private(set) var transcript: String = ""

    /// View convenience (matches your UI usage)
    var isDictating: Bool { isRecording }

    // MARK: - Session output (where we write text)

    // We store a closure instead of storing Binding directly.
    private var applyText: ((String) -> Void)? = nil

    // MARK: - Internals

    private let recognizer = SFSpeechRecognizer()
    private let audioEngine = AVAudioEngine()

    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    // Throttle partial updates. 200ms ~ 5 updates/sec.
    private let partialThrottleNanoseconds: UInt64 = 200_000_000
    private var pendingPartialText: String = ""
    private var partialUpdateTask: Task<Void, Never>? = nil
    private var sessionBaseText: String = ""

    // MARK: - Public API

    func toggleDictation(into text: Binding<String>) {
        if isRecording {
            stop()
            return
        }

        // Capture where to write the transcript for this session.
        // Capture the starting text so we can append instead of overwrite
        self.sessionBaseText = text.wrappedValue

        self.applyText = { [weak self] newValue in
            guard let self else { return }

            let base = self.sessionBaseText.trimmingCharacters(in: .whitespacesAndNewlines)
            let spoken = newValue.trimmingCharacters(in: .whitespacesAndNewlines)

            // If there's no base yet, just use the dictation.
            guard !base.isEmpty else {
                text.wrappedValue = spoken
                return
            }

            // If there's no spoken text yet, keep the base.
            guard !spoken.isEmpty else {
                text.wrappedValue = self.sessionBaseText
                return
            }

            // Simple separator rule: space unless base already ends with whitespace.
            let sep = self.sessionBaseText.last?.isWhitespace == true ? "" : " "
            text.wrappedValue = self.sessionBaseText + sep + spoken
        }

        Task {
            let ok = await requestPermissionsIfNeeded()
            guard ok else {
                self.applyText = nil
                return
            }
            await startRecording()
        }
    }

    func stop() {
        stopInternal(clearWriter: true)
    }

    // MARK: - Permissions

    func requestPermissionsIfNeeded() async -> Bool {
        lastError = nil

        // Speech permission
        let speechOK: Bool = await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { status in
                cont.resume(returning: status == .authorized)
            }
        }

        guard speechOK else {
            lastError = "Speech recognition permission denied."
            return false
        }

        // Mic permission
        let micOK: Bool = await withCheckedContinuation { cont in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                cont.resume(returning: granted)
            }
        }

        guard micOK else {
            lastError = "Microphone permission denied."
            return false
        }

        return true
    }

    // MARK: - Core recording

    private func startRecording() async {
        lastError = nil
        guard !isRecording else { return }

        // Clear any previous task/engine taps, but do NOT clear transcript.
        stopInternal(clearWriter: false)

        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        self.request = req

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.request?.append(buffer)
        }

        audioEngine.prepare()

        do {
            try audioEngine.start()
        } catch {
            lastError = "Could not start audio engine: \(error.localizedDescription)"
            stopInternal(clearWriter: false)
            return
        }

        isRecording = true

        task = recognizer?.recognitionTask(with: req) { [weak self] result, error in
            guard let self else { return }

            if let error {
                self.lastError = error.localizedDescription
                self.stopInternal(clearWriter: true)
                return
            }

            guard let result else { return }
            let text = result.bestTranscription.formattedString

            if result.isFinal {
                self.applyFinal(text)
                self.stopInternal(clearWriter: true)
            } else {
                self.applyPartialThrottled(text)
            }
        }
    }

    // MARK: - Apply transcript

    private func applyFinal(_ text: String) {
        // Cancel any pending partial update; final wins.
        partialUpdateTask?.cancel()
        partialUpdateTask = nil
        pendingPartialText = ""

        transcript = text

        // Defer UI write to next runloop tick to reduce layout recursion warnings.
        let writer = applyText
        DispatchQueue.main.async {
            writer?(text)
        }
    }

    private func applyPartialThrottled(_ text: String) {
        pendingPartialText = text

        partialUpdateTask?.cancel()
        partialUpdateTask = Task { [weak self] in
            guard let self else { return }
            do { try await Task.sleep(nanoseconds: self.partialThrottleNanoseconds) }
            catch { return }

            guard !Task.isCancelled else { return }
            guard self.isRecording else { return }

            let toApply = self.pendingPartialText
            self.transcript = toApply

            let writer = self.applyText
            DispatchQueue.main.async {
                writer?(toApply)
            }
        }
    }

    // MARK: - Stop / cleanup

    private func stopInternal(clearWriter: Bool) {
        // Cancel any pending throttled UI update
        partialUpdateTask?.cancel()
        partialUpdateTask = nil
        pendingPartialText = ""

        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }

        request?.endAudio()
        request = nil

        task?.cancel()
        task = nil

        isRecording = false

        if clearWriter {
            applyText = nil
            sessionBaseText = ""
        }

        // IMPORTANT: We do NOT clear `transcript` here.
        // We also do NOT clear the bound text field here.
    }
}
