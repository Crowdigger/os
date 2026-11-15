import SwiftUI
import UIKit
import PhotosUI

struct PhotoPicker: UIViewControllerRepresentable {
    enum Source { case camera, library }
    let source: Source
    let onImage: (UIImage) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIViewController {
        switch source {
        case .camera:
            let controller = UIImagePickerController()
            controller.sourceType = .camera
            controller.delegate = context.coordinator
            return controller
        case .library:
            var configuration = PHPickerConfiguration(photoLibrary: .shared())
            configuration.filter = .images
            configuration.selectionLimit = 1
            let controller = PHPickerViewController(configuration: configuration)
            controller.delegate = context.coordinator
            return controller
        }
    }
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate, PHPickerViewControllerDelegate {
        let owner: PhotoPicker
        init(_ owner: PhotoPicker) { self.owner = owner }
        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage { owner.onImage(image) }
            else { owner.onCancel() }
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { owner.onCancel() }
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard let provider = results.first?.itemProvider, provider.canLoadObject(ofClass: UIImage.self) else {
                DispatchQueue.main.async { self.owner.onCancel() }
                return
            }
            provider.loadObject(ofClass: UIImage.self) { object, _ in
                DispatchQueue.main.async {
                    if let image = object as? UIImage { self.owner.onImage(image) }
                    else { self.owner.onCancel() }
                }
            }
        }
    }
}

struct StoredPhotoView: View {
    @EnvironmentObject var store: PieceStore
    let name: String
    var body: some View {
        Group {
            if let image = store.image(name) {
                Image(uiImage: image).resizable().scaledToFit()
            } else {
                ContentUnavailableView("Foto indisponível", systemImage: "photo")
            }
        }
        .frame(maxWidth: .infinity)
        .background(Color.black.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 3))
    }
}
