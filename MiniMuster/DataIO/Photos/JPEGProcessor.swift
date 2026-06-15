import Foundation
#if canImport(UIKit)
import UIKit
#endif

enum PhotoError: LocalizedError {
    case tooManyPhotos
    case unreadableImage
    case tooLarge
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .tooManyPhotos: "This unit already has the maximum number of photos."
        case .unreadableImage: "Could not read the selected image."
        case .tooLarge: "The image is too large to import."
        case .encodingFailed: "Could not save the image."
        }
    }
}

/// Resize and compress incoming image data to a storage-friendly JPEG.
enum JPEGProcessor {
    static func normalize(_ data: Data) throws -> Data {
        guard data.count <= Limits.maxPhotoBytes else { throw PhotoError.tooLarge }
#if canImport(UIKit)
        guard let image = UIImage(data: data) else { throw PhotoError.unreadableImage }
        let resized = resize(image, maxDimension: CGFloat(Limits.maxPhotoDimension))
        guard let jpeg = resized.jpegData(compressionQuality: Limits.jpegQuality) else {
            throw PhotoError.encodingFailed
        }
        return jpeg
#else
        return data
#endif
    }

#if canImport(UIKit)
    private static func resize(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let longest = max(size.width, size.height)
        guard longest > maxDimension else { return image }
        let scale = maxDimension / longest
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
#endif
}
