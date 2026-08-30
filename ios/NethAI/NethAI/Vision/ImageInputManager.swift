import Foundation
import UIKit
import PhotosUI
import SwiftUI

// MARK: - ImageInputManager
// Handles camera capture and Photos picker for vision-capable LLMs.

@MainActor
final class ImageInputManager: NSObject, ObservableObject {
    @Published var attachedImages: [AttachedImage] = []

    func addImage(_ data: Data) {
        let thumbnail = makeThumbnail(from: data, maxDim: 256)
        attachedImages.append(AttachedImage(imageData: data, thumbnail: thumbnail))
    }

    func removeImage(_ id: UUID) {
        attachedImages.removeAll { $0.id == id }
    }

    func clear() {
        attachedImages.removeAll()
    }

    private func makeThumbnail(from data: Data, maxDim: CGFloat) -> Data? {
        guard let img = UIImage(data: data) else { return nil }
        let scale = min(maxDim / img.size.width, maxDim / img.size.height, 1.0)
        let newSize = CGSize(width: img.size.width * scale, height: img.size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.jpegData(withCompressionQuality: 0.7) { _ in
            img.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

// MARK: - PHPicker bridge

struct PhotosPickerBridge: UIViewControllerRepresentable {
    @Binding var pickedImageData: Data?
    var allowsMultiple: Bool = false

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.selectionLimit = allowsMultiple ? 0 : 1
        config.filter = .images
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotosPickerBridge
        init(_ parent: PhotosPickerBridge) { self.parent = parent }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard let result = results.first else { return }
            if result.itemProvider.canLoadObject(ofClass: UIImage.self) {
                result.itemProvider.loadObject(ofClass: UIImage.self) { obj, _ in
                    if let img = obj as? UIImage, let data = img.jpegData(compressionQuality: 0.85) {
                        DispatchQueue.main.async {
                            self.parent.pickedImageData = data
                        }
                    }
                }
            }
        }
    }
}
