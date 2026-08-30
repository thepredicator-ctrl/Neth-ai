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

        guard FileManager.default.fileExists(atPath: url.path) else {
            throw LLMError.modelNotFound(url.path)
        }

        // Quick magic-byte check for GGUF
        if let fh = try? FileHandle(forReadingFrom: url) {
            let header = fh.readData(ofLength: 4)
            try? fh.close()
            let ggufMagic: [UInt8] = [0x47, 0x47, 0x55, 0x46] // "GGUF"
            if header != Data(ggufMagic) {
                logger.error("File at \(url.path) does not have GGUF magic header")
                throw LLMError.loadFailed("File is not a valid GGUF model.")
            }
        }

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
            logger.info("Loaded model: \(url.lastPathComponent) (gpuLayers=\(gpuLayers))")
        } catch {
            logger.error("Model load failed: \(String(describing: error))")
            throw LLMError.loadFailed(String(describing: error))
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
                    let stream = actor.generate(prompt: prompt, params: sampling)
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
        let ttft = start.duration(to: firstTok).components.seconds
        let totalDur = start.duration(to: now).components.seconds
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
