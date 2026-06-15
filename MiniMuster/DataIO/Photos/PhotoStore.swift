import Foundation
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

@MainActor
enum PhotoStore {
    static func addPhoto(from imageData: Data, to unit: Unit, stageKey: String,
                         memberIndex: Int? = nil, in ctx: ModelContext) throws -> ModelPhoto {
        guard unit.photos.count < Limits.maxPhotosPerUnit else { throw PhotoError.tooManyPhotos }
        let jpeg = try JPEGProcessor.normalize(imageData)
        let fileName = try PhotoFileStore.writeJPEG(jpeg)
        let photo = ModelPhoto(stageKey: stageKey, fileName: fileName, memberIndex: memberIndex)
        photo.sortIndex = (unit.photos.map(\.sortIndex).max() ?? -1) + 1
        if unit.photos.isEmpty { photo.isCover = true }
        photo.unit = unit
        ctx.insert(photo)
        try ctx.save()
        return photo
    }

    static func delete(_ photo: ModelPhoto, in ctx: ModelContext) {
        PhotoFileStore.delete(fileName: photo.fileName)
        let unit = photo.unit
        let wasCover = photo.isCover
        ctx.delete(photo)
        if wasCover, let unit {
            let remaining = unit.photos.sorted {
                if $0.sortIndex != $1.sortIndex { return $0.sortIndex < $1.sortIndex }
                return $0.createdAt < $1.createdAt
            }
            remaining.first?.isCover = true
        }
        try? ctx.save()
    }

    static func setCover(_ photo: ModelPhoto, in ctx: ModelContext) {
        guard let unit = photo.unit else { return }
        for p in unit.photos { p.isCover = (p.id == photo.id) }
        try? ctx.save()
    }

    static func purgeFiles(for unit: Unit) {
        for photo in unit.photos {
            PhotoFileStore.delete(fileName: photo.fileName)
        }
    }

#if canImport(UIKit)
    static func loadImage(_ photo: ModelPhoto) -> UIImage? {
        guard let data = PhotoFileStore.data(for: photo.fileName) else { return nil }
        return UIImage(data: data)
    }
#endif
}
