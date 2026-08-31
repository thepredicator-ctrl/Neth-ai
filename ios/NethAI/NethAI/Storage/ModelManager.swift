import Foundation
import UIKit

// MARK: - ModelManager
// Imports, deletes, and lists GGUF models stored in the app's Documents directory.
// Documents directory is exposed via Files app so users can AirDrop / iCloud / paste models.
//
// CRITICAL: Import uses NSFileCoordinator to properly handle iCloud Drive placeholders.
// Files picked from iCloud Drive may not be downloaded yet — we must trigger the download
// and verify the copied file matches the source size before declaring success.

final class ModelManager: @unchecked Sendable {
    static let shared = ModelManager()

    private let fm = FileManager.default

    var modelsDirectory: URL {
        let base = try! fm.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let dir = base.appendingPathComponent("Models", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private init() {}

    // MARK: List

    func listInstalledModels() async -> [InstalledModel] {
        var models: [InstalledModel] = []
        let urls = (try? fm.contentsOfDirectory(at: modelsDirectory, includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey], options: [.skipsHiddenFiles])) ?? []
        for url in urls {
            guard url.pathExtension.lowercased() == "gguf" else { continue }
            let attrs = try? fm.attributesOfItem(atPath: url.path)
            let size = (attrs?[.size] as? NSNumber)?.int64Value ?? 0
            let date = (attrs?[.modificationDate] as? Date) ?? Date()
            models.append(InstalledModel(
                fileName: url.lastPathComponent,
                fileSize: size,
                dateAdded: date
            ))
        }
        return models.sorted { $0.displayName < $1.displayName }
    }

    // MARK: Import

    enum ImportError: LocalizedError {
        case fileExists
        case insufficientSpace(needed: Int64, free: Int64)
        case invalidGGUF
        case interrupted
        case downloadFailed(String)
        case copyFailed(String)
        case sizeMismatch(expected: Int64, actual: Int64)
        case unknown(String)

        var errorDescription: String? {
            switch self {
            case .fileExists: return "A model with this name already exists."
            case .insufficientSpace(let n, let f):
                return "Not enough free space. Need \(ByteCountFormatter.string(fromByteCount: n, countStyle: .file)), have \(ByteCountFormatter.string(fromByteCount: f, countStyle: .file))."
            case .invalidGGUF: return "This file does not have a valid GGUF header. Make sure you downloaded a proper .gguf model file."
            case .interrupted: return "Import was interrupted."
            case .downloadFailed(let m): return "Could not download file from iCloud: \(m)"
            case .copyFailed(let m): return "Failed to copy model file: \(m)"
            case .sizeMismatch(let expected, let actual):
                return "Copy verification failed — expected \(ByteCountFormatter.string(fromByteCount: expected, countStyle: .file)) but got \(ByteCountFormatter.string(fromByteCount: actual, countStyle: .file)). The file may be corrupted or still downloading."
            case .unknown(let m): return m
            }
        }
    }

    /// Sanitize a filename so it's safe for llama.cpp's C library (no spaces, no special chars).
    private func sanitizeFileName(_ name: String) -> String {
        let ext = (name as NSString).pathExtension.lowercased()
        var base = (name as NSString).deletingPathExtension
        // replace spaces and special chars with underscores
        base = base.replacingOccurrences(of: " ", with: "_")
        base = base.replacingOccurrences(of: "-", with: "_")
        base = base.replacingOccurrences(of: "(", with: "_")
        base = base.replacingOccurrences(of: ")", with: "_")
        base = base.replacingOccurrences(of: "[", with: "_")
        base = base.replacingOccurrences(of: "]", with: "_")
        base = base.replacingOccurrences(of: "{", with: "_")
        base = base.replacingOccurrences(of: "}", with: "_")
        base = base.replacingOccurrences(of: ",", with: "_")
        base = base.replacingOccurrences(of: ";", with: "_")
        base = base.replacingOccurrences(of: "'", with: "_")
        base = base.replacingOccurrences(of: "\"", with: "_")
        // collapse multiple underscores
        while base.contains("__") { base = base.replacingOccurrences(of: "__", with: "_") }
        // trim leading/trailing underscores
        base = base.trimmingCharacters(in: CharacterSet(charactersIn: "_"))
        if base.isEmpty { base = "model" }
        return ext.isEmpty ? base : "\(base).\(ext)"
    }

    /// Trigger iCloud download if the URL is an iCloud placeholder.
    private func ensureDownloaded(at url: URL) async throws {
        // Check if this is an iCloud item that needs downloading
        let resourceKeys: [URLResourceKey] = [
            .isUbiquitousItemKey,
            .ubiquitousItemDownloadingStatusKey,
            .ubiquitousItemDownloadingErrorKey
        ]
        let values = try? url.resourceValues(forKeys: Set(resourceKeys))

        if let isUbiquitous = values?.isUbiquitousItem, isUbiquitous {
            let status = values?.ubiquitousItemDownloadingStatus ?? .current
            if status != .current {
                // trigger download
                try? FileManager.default.startDownloadingUbiquitousItem(at: url)
                // wait for download to complete (poll up to 60s)
                let start = Date()
                while Date().timeIntervalSince(start) < 60 {
                    let v = try? url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])
                    if v?.ubiquitousItemDownloadingStatus == .current { return }
                    try? await Task.sleep(for: .milliseconds(500))
                }
                // final check
                let finalStatus = (try? url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey]))?.ubiquitousItemDownloadingStatus
                if finalStatus != .current {
                    throw ImportError.downloadFailed("Timed out waiting for iCloud download. Make sure you have a network connection.")
                }
            }
        }
    }

    func importModel(from sourceURL: URL, replace: Bool = false) async throws -> InstalledModel {
        // access security scoped resource if needed
        let needsScopedAccess = sourceURL.startAccessingSecurityScopedResource()
        defer { if needsScopedAccess { sourceURL.stopAccessingSecurityScopedResource() } }

        // Step 1: trigger iCloud download if needed
        try await ensureDownloaded(at: sourceURL)

        // Step 2: read the full file data via NSFileCoordinator (handles security-scoped + iCloud)
        let sourceData: Data
        do {
            sourceData = try await readCoordinatedData(from: sourceURL)
        } catch {
            throw ImportError.copyFailed("Could not read source file: \(error.localizedDescription)")
        }

        guard sourceData.count > 0 else {
            throw ImportError.copyFailed("Source file is empty. It may not have downloaded from iCloud yet.")
        }

        // Step 3: validate GGUF magic
        guard sourceData.count >= 4 else {
            throw ImportError.invalidGGUF
        }
        let ggufMagic: [UInt8] = [0x47, 0x47, 0x55, 0x46] // "GGUF"
        let header = Array(sourceData.prefix(4))
        guard header == ggufMagic else {
            throw ImportError.invalidGGUF
        }

        // Step 4: sanitize filename + compute destination
        let safeName = sanitizeFileName(sourceURL.lastPathComponent)
        let dest = modelsDirectory.appendingPathComponent(safeName)
        if fm.fileExists(atPath: dest.path) && !replace {
            throw ImportError.fileExists
        }

        // Step 5: free space check
        let srcSize = Int64(sourceData.count)
        if let attrs = try? fm.attributesOfFileSystem(forPath: modelsDirectory.path),
           let free = attrs[.systemFreeSize] as? NSNumber {
            if free.int64Value < srcSize {
                throw ImportError.insufficientSpace(needed: srcSize, free: free.int64Value)
            }
        }

        // Step 6: remove existing if replacing
        if fm.fileExists(atPath: dest.path) {
            try? fm.removeItem(at: dest)
        }

        // Step 7: write data atomically to destination
        do {
            try sourceData.write(to: dest, options: .atomic)
        } catch {
            throw ImportError.copyFailed("Could not write model file: \(error.localizedDescription)")
        }

        // Step 8: verify the written file
        guard let destAttrs = try? fm.attributesOfItem(atPath: dest.path),
              let writtenSize = (destAttrs[.size] as? NSNumber)?.int64Value else {
            throw ImportError.copyFailed("Could not verify written file.")
        }
        if writtenSize != srcSize {
            try? fm.removeItem(at: dest)
            throw ImportError.sizeMismatch(expected: srcSize, actual: writtenSize)
        }

        // Step 9: re-verify GGUF magic on the written file (paranoid)
        if let fh = try? FileHandle(forReadingFrom: dest) {
            let writtenHeader = fh.readData(ofLength: 4)
            try? fh.close()
            if writtenHeader != Data(ggufMagic) {
                try? fm.removeItem(at: dest)
                throw ImportError.invalidGGUF
            }
        }

        return InstalledModel(fileName: dest.lastPathComponent, fileSize: writtenSize)
    }

    /// Read file data using NSFileCoordinator (proper handling of security-scoped + iCloud resources).
    private func readCoordinatedData(from url: URL) async throws -> Data {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, Error>) in
            let coordinator = NSFileCoordinator()
            var error: NSError?
            coordinator.coordinate(readingItemAt: url, options: [.withoutChanges], error: &error) { coordinatedURL in
                do {
                    let data = try Data(contentsOf: coordinatedURL, options: [.uncached])
                    continuation.resume(returning: data)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
            if let error {
                continuation.resume(throwing: error)
            }
        }
    }

    // MARK: Delete

    func delete(_ model: InstalledModel) throws {
        let url = modelsDirectory.appendingPathComponent(model.fileName)
        try? fm.removeItem(at: url)
    }

    // MARK: Path

    func path(for model: InstalledModel) -> URL {
        modelsDirectory.appendingPathComponent(model.fileName)
    }

    // MARK: Verify a model file is still loadable (used before inference)
    func verifyModel(_ model: InstalledModel) -> Bool {
        let url = path(for: model)
        guard fm.fileExists(atPath: url.path) else { return false }
        guard let attrs = try? fm.attributesOfItem(atPath: url.path),
              let size = (attrs[.size] as? NSNumber)?.int64Value, size > 0 else {
            return false
        }
        // check GGUF magic
        guard let fh = try? FileHandle(forReadingFrom: url) else { return false }
        let header = fh.readData(ofLength: 4)
        try? fh.close()
        return header == Data([0x47, 0x47, 0x55, 0x46])
    }
}
