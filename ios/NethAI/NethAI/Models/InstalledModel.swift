import Foundation
import UIKit

struct InstalledModel: Identifiable, Codable, Sendable, Hashable {
    var id: UUID
    var fileName: String       // e.g. "qwen2-7b-instruct.Q4_K_M.gguf"
    var displayName: String    // e.g. "Qwen2 7B Instruct"
    var fileSize: Int64        // bytes
    var dateAdded: Date
    var quantization: String?  // e.g. "Q4_K_M"
    var parameterCount: String? // e.g. "7B"
    var supportsVision: Bool

    init(id: UUID = UUID(), fileName: String, displayName: String? = nil, fileSize: Int64, dateAdded: Date = Date(), quantization: String? = nil, parameterCount: String? = nil, supportsVision: Bool = false) {
        self.id = id
        self.fileName = fileName
        self.displayName = displayName ?? Self.guessDisplayName(fileName)
        self.fileSize = fileSize
        self.dateAdded = dateAdded
        self.quantization = quantization ?? Self.guessQuant(fileName)
        self.parameterCount = parameterCount ?? Self.guessParams(fileName)
        self.supportsVision = Self.guessVision(fileName)
    }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }

    static func guessDisplayName(_ fileName: String) -> String {
        var name = (fileName as NSString).deletingPathExtension
        name = name.replacingOccurrences(of: "_", with: " ")
        name = name.replacingOccurrences(of: "-", with: " ")
        return name.capitalized
    }

    static func guessQuant(_ fileName: String) -> String? {
        // common quantization tags
        let patterns = ["Q8_0", "Q6_K", "Q5_K_M", "Q5_K_S", "Q5_1", "Q5_0", "Q4_K_M", "Q4_K_S", "Q4_1", "Q4_0", "Q3_K_M", "Q3_K_S", "Q3_K_L", "Q2_K", "F16", "F32"]
        let upper = fileName.uppercased()
        return patterns.first(where: { upper.contains($0) })
    }

    static func guessParams(_ fileName: String) -> String? {
        // look for patterns like "7b", "13b", "0.5b", "1.5b", "70b"
        let regex = try? NSRegularExpression(pattern: "(\\d+(?:\\.\\d+)?)[bB]")
        let range = NSRange(fileName.startIndex..<fileName.endIndex, in: fileName)
        if let m = regex?.firstMatch(in: fileName, range: range),
           let r = Range(m.range(at: 1), in: fileName) {
            return "\(fileName[r])B"
        }
        return nil
    }

    static func guessVision(_ fileName: String) -> Bool {
        let lower = fileName.lowercased()
        let keywords = ["vision", "vl", "llava", "moondream", "qwen2-vl", "minicpm-v", "phi-3-vision", "internvl"]
        return keywords.contains(where: { lower.contains($0) })
    }
}
