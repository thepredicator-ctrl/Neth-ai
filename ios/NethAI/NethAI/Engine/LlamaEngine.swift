import Foundation
import SwiftLlama
import os.log

// MARK: - LlamaEngine
// Wraps `profclaw/swift-llama` (which uses official pre-built llama.cpp XCFramework).
// Supports GGUF models, Metal acceleration, and streaming generation.

final class LlamaEngine: LLMEngine, @unchecked Sendable {
    private let logger = Logger(subsystem: "ai.neth.NethAI", category: "LlamaEngine")
    private var actor: LlamaActor?
    private var model: LlamaModel?
    private let lock = NSLock()

    private(set) var loadedModelName: String? = nil
    private(set) var contextSize: Int = 4096
    private(set) var metalAccelerated: Bool = true
    private var generationStart: ContinuousClock.Instant?
    private var firstTokenTime: ContinuousClock.Instant?
    private var generatedTokenCount: Int = 0

    var isLoaded: Bool {
        lock.lock(); defer { lock.unlock() }
        return actor != nil
    }

    func loadModel(at url: URL, gpuLayers: Int) async throws {
        // unload any existing model first
        unloadModelInternal()

        let fm = FileManager.default

        // Pre-flight 1: file exists
        guard fm.fileExists(atPath: url.path) else {
            logger.error("Model file does not exist at path: \(url.path)")
            throw LLMError.modelNotFound(url.path)
        }

        // Pre-flight 2: file is not empty
        guard let attrs = try? fm.attributesOfItem(atPath: url.path),
              let size = (attrs[.size] as? NSNumber)?.int64Value, size > 0 else {
            logger.error("Model file is empty or unreadable: \(url.path)")
            throw LLMError.loadFailed("Model file is empty. It may not have downloaded from iCloud properly. Try re-importing the model.")
        }

        // Pre-flight 3: GGUF magic header
        guard let fh = try? FileHandle(forReadingFrom: url) else {
            logger.error("Could not open model file for reading: \(url.path)")
            throw LLMError.loadFailed("Could not open model file for reading.")
        }
        let header = fh.readData(ofLength: 4)
        try? fh.close()
        let ggufMagic: [UInt8] = [0x47, 0x47, 0x55, 0x46] // "GGUF"
        if header != Data(ggufMagic) {
            logger.error("File at \(url.path) does not have GGUF magic header. Got: \(header.map { String(format: "%02X", $0) }.joined())")
            throw LLMError.loadFailed("File is not a valid GGUF model. The file may be corrupted or in an unsupported format.")
        }

        logger.info("Pre-flight checks passed for \(url.lastPathComponent) (\(size) bytes). Loading via llama.cpp...")

        do {
            let gpu: GPULayers = (gpuLayers > 0) ? .all : .none
            let config = ModelConfig(
                contextSize: 4096,
                batchSize: 512,
                gpuLayers: gpu,
                threads: 0
            )
            let m = try LlamaModel(path: url.path, config: config)
            let a = try LlamaActor(model: m, params: .balanced)
            lock.lock()
            self.model = m
            self.actor = a
            self.loadedModelName = url.lastPathComponent
            self.metalAccelerated = gpuLayers > 0
            lock.unlock()
            logger.info("Loaded model: \(url.lastPathComponent) (gpuLayers=\(gpuLayers), size=\(size) bytes)")
        } catch {
            logger.error("Model load failed: \(String(describing: error))")
            // Provide a user-friendly error message
            let errMsg: String
            if let llamaErr = error as? SwiftLlama.LlamaError {
                switch llamaErr {
                case .failedToLoadModel(let path):
                    errMsg = "llama.cpp could not load this model. The file may be corrupted, use an unsupported architecture, or exceed available memory. Path: \(path)"
                case .invalidModelPath(let path):
                    errMsg = "Invalid model path: \(path)"
                case .failedToCreateContext:
                    errMsg = "Failed to create inference context. The model may be too large for this device's memory."
                default:
                    errMsg = String(describing: error)
                }
            } else {
                errMsg = String(describing: error)
            }
            throw LLMError.loadFailed(errMsg)
        }
    }

    func unloadModel() async {
        unloadModelInternal()
    }

    private func unloadModelInternal() {
        lock.lock()
        actor = nil
        model = nil
        loadedModelName = nil
        lock.unlock()
    }

    func generate(prompt: String, params: NethSamplingParams) -> AsyncThrowingStream<EngineToken, Error> {
        let sampling = SwiftLlama.SamplingParams(
            temperature: params.temperature,
            topP: params.topP,
            topK: Int32(params.topK),
            repeatPenalty: params.repeatPenalty,
            maxTokens: Int32(params.maxTokens)
        )

        return AsyncThrowingStream { continuation in
            Task { [weak self] in
                guard let self else {
                    continuation.finish(throwing: LLMError.inferenceFailed("Engine deallocated"))
                    return
                }
                self.lock.lock()
                guard let actor = self.actor else {
                    self.lock.unlock()
                    continuation.finish(throwing: LLMError.noModelLoaded)
                    return
                }
                self.lock.unlock()

                self.generationStart = ContinuousClock.now
                self.firstTokenTime = nil
                self.generatedTokenCount = 0

                do {
                    let stream = await actor.generate(prompt: prompt, params: sampling)
                    for try await token in stream {
                        self.generatedTokenCount += 1
                        if self.firstTokenTime == nil {
                            self.firstTokenTime = ContinuousClock.now
                        }
                        continuation.yield(EngineToken(text: token, isFinal: false, stats: nil))
                    }
                    // Final stats
                    let stats = self.computeStats(promptTokens: 0)
                    continuation.yield(EngineToken(text: "", isFinal: true, stats: stats))
                    continuation.finish()
                } catch {
                    if let err = error as? SwiftLlama.LlamaError, case .cancelled = err {
                        let stats = self.computeStats(promptTokens: 0)
                        continuation.yield(EngineToken(text: "", isFinal: true, stats: stats))
                        continuation.finish()
                    } else {
                        continuation.finish(throwing: LLMError.inferenceFailed(String(describing: error)))
                    }
                }
            }
        }
    }

    private func computeStats(promptTokens: Int) -> InferenceStats {
        let now = ContinuousClock.now
        let start = generationStart ?? now
        let firstTok = firstTokenTime ?? now
        let ttft = durationSeconds(from: start, to: firstTok)
        let totalDur = durationSeconds(from: start, to: now)
        let toks = generatedTokenCount
        let tps = totalDur > 0 ? Double(toks) / totalDur : 0
        let mem = reportResidentMemoryMB()
        return InferenceStats(
            tokensPerSecond: tps,
            timeToFirstToken: ttft,
            totalTokens: toks,
            promptTokens: promptTokens,
            generationDuration: totalDur,
            contextSize: contextSize,
            memoryResidentMB: mem,
            metalAccelerated: metalAccelerated
        )
    }

    private func durationSeconds(from a: ContinuousClock.Instant, to b: ContinuousClock.Instant) -> Double {
        let comps = a.duration(to: b).components
        return Double(comps.seconds) + Double(comps.attoseconds) * 1e-18
    }

    private func reportResidentMemoryMB() -> Double {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let kerr = withUnsafeMutablePointer(to: &info) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        if kerr == KERN_SUCCESS {
            return Double(info.phys_footprint) / (1024.0 * 1024.0)
        }
        return 0
    }

    func cancel() async {
        lock.lock()
        let actor = self.actor
        lock.unlock()
        await actor?.cancel()
    }
}
