import Foundation
import SwiftData
import Testing
#if canImport(UIKit)
import UIKit
#endif
@testable import MiniMuster

@MainActor
struct PhotoStoreTests {
    private let db = TestDatabase()

    @Test("addPhoto stores JPEG and sets first photo as cover")
    func addPhotoCover() throws {
        let army = Army(name: "Test", game: "40k", faction: "Ultramarines")
        db.context.insert(army)
        let unit = Unit(name: "Captain", state: "Primed")
        unit.army = army
        db.context.insert(unit)

        let data = try #require(sampleJPEGData())
        let photo = try PhotoStore.addPhoto(from: data, to: unit, stageKey: "Primed", in: db.context)

        #expect(photo.isCover)
        #expect(photo.stageKey == "Primed")
        #expect(unit.photos.count == 1)
        #expect(PhotoFileStore.data(for: photo.fileName) != nil)
#if canImport(UIKit)
        #expect(PhotoStore.loadImage(photo) != nil)
#endif
    }

    @Test("delete promotes next photo to cover")
    func deletePromotesCover() throws {
        let unit = Unit(name: "Captain", state: "Primed")
        db.context.insert(unit)
        let first = try PhotoStore.addPhoto(from: try #require(sampleJPEGData()),
                                            to: unit, stageKey: "Primed", in: db.context)
        let second = try PhotoStore.addPhoto(from: try #require(sampleJPEGData()),
                                             to: unit, stageKey: "Detailed", in: db.context)
        PhotoStore.setCover(second, in: db.context)
        PhotoStore.delete(second, in: db.context)

        #expect(unit.photos.count == 1)
        #expect(unit.coverPhoto?.id == first.id)
        #expect(unit.coverPhoto?.isCover == true)
    }

    @Test("purgeFiles removes disk files for a unit")
    func purgeFiles() throws {
        let unit = Unit(name: "Captain", state: "Primed")
        db.context.insert(unit)
        let photo = try PhotoStore.addPhoto(from: try #require(sampleJPEGData()),
                                            to: unit, stageKey: "Primed", in: db.context)
        let fileName = photo.fileName
        PhotoStore.purgeFiles(for: unit)
        #expect(PhotoFileStore.data(for: fileName) == nil)
    }

    @Test("enforces max photos per unit")
    func maxPhotos() throws {
        let unit = Unit(name: "Captain", state: "Primed")
        db.context.insert(unit)
        let data = try #require(sampleJPEGData())
        for _ in 0..<Limits.maxPhotosPerUnit {
            _ = try PhotoStore.addPhoto(from: data, to: unit, stageKey: "Primed", in: db.context)
        }
        #expect(throws: PhotoError.tooManyPhotos) {
            _ = try PhotoStore.addPhoto(from: data, to: unit, stageKey: "Primed", in: db.context)
        }
    }
}

@MainActor
struct StageEventStoreTests {
    private let db = TestDatabase()

    @Test("setState records a stage event")
    func setStateEvent() {
        let unit = Unit(name: "Captain", state: "Primed")
        db.context.insert(unit)
        ArmyStore.setState(unit, "Detailed", in: db.context)

        #expect(unit.stageEvents.count == 1)
        let event = unit.orderedStageEvents.first
        #expect(event?.stageKey == "Detailed")
        #expect(event?.previousStageKey == "Primed")
        #expect(event?.memberIndex == nil)
    }

    @Test("advance records unit stage event")
    func advanceEvent() {
        let pipeline = DefaultPipeline.stages
        let unit = Unit(name: "Captain", state: "Primed")
        db.context.insert(unit)
        ArmyStore.advance(unit, pipeline: pipeline, in: db.context)

        #expect(unit.state == "Base Coated")
        #expect(unit.stageEvents.contains { $0.stageKey == "Base Coated" })
    }
}

#if canImport(UIKit)
private func sampleJPEGData() -> Data? {
    let size = CGSize(width: 32, height: 32)
    let renderer = UIGraphicsImageRenderer(size: size)
    let image = renderer.image { ctx in
        UIColor.systemBlue.setFill()
        ctx.fill(CGRect(origin: .zero, size: size))
    }
    return image.jpegData(compressionQuality: 0.9)
}
#else
private func sampleJPEGData() -> Data? { nil }
#endif
