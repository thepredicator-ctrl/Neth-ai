import Foundation
import UIKit

// MARK: - ModelManager
// Imports, deletes, and lists GGUF models stored in the app's Documents directory.
// Documents directory is exposed via Files app so users can AirDrop / iCloud / paste models.

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
        case unknown(String)

        var errorDescription: String? {
            switch self {
            case .fileExists: return "A model with this name already exists."
            case .insufficientSpace(let n, let f):
                return "Not enough free space. Need \(ByteCountFormatter.string(fromByteCount: n, countStyle: .file)), have \(ByteCountFormatter.string(fromByteCount: f, countStyle: .file))."
            case .invalidGGUF: return "This file does not have a valid GGUF header."
            case .interrupted: return "Import was interrupted."
            case .unknown(let m): return m
            }
        }
    }

    func importModel(from sourceURL: URL, replace: Bool = false) async throws -> InstalledModel {
        // access security scoped resource if needed
        let needsScopedAccess = sourceURL.startAccessingSecurityScopedResource()
        defer { if needsScopedAccess { sourceURL.stopAccessingSecurityScopedResource() } }

        // validate GGUF magic
        guard let fh = try? FileHandle(forReadingFrom: sourceURL) else {
            throw ImportError.invalidGGUF
        }
        let header = fh.readData(ofLength: 4)
        try? fh.close()
        let ggufMagic: [UInt8] = [0x47, 0x47, 0x55, 0x46]
        guard header == Data(ggufMagic) else {
            throw ImportError.invalidGGUF
        }

        let dest = modelsDirectory.appendingPathComponent(sourceURL.lastPathComponent)
        if fm.fileExists(atPath: dest.path) && !replace {
            throw ImportError.fileExists
        }

        // free space check
        if let attrs = try? fm.attributesOfFileSystem(forPath: modelsDirectory.path),
           let free = attrs[.systemFreeSize] as? NSNumber {
            let srcSize = (try? fm.attributesOfItem(atPath: sourceURL.path)[.size] as? NSNumber)?.int64Value ?? 0
            if free.int64Value < srcSize {
                throw ImportError.insufficientSpace(needed: srcSize, free: free.int64Value)
            }
        }

        // copy with coordinator (handles iCloud/Files sources properly)
        if fm.fileExists(atPath: dest.path) {
            try? fm.removeItem(at: dest)
        }
        do {
            try fm.copyItem(at: sourceURL, to: dest)
        } catch {
            // if copy fails, try data write
            if let data = try? Data(contentsOf: sourceURL) {
                try data.write(to: dest, options: .atomic)
            } else {
                throw ImportError.unknown(String(describing: error))
            }
        }

        let attrs = try? fm.attributesOfItem(atPath: dest.path)
        let size = (attrs?[.size] as? NSNumber)?.int64Value ?? 0
        return InstalledModel(fileName: dest.lastPathComponent, fileSize: size)
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
}
