import PhotosUI
import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

/// Photo gallery and import for a single unit.
@MainActor
struct UnitPhotoSection: View {
    @Environment(\.modelContext) private var context
    @Environment(BannerCenter.self) private var banner

    @Bindable var unit: Unit
    let pipeline: [PipelineStage]

    @State private var pickerItem: PhotosPickerItem?
    @State private var photoToDelete: ModelPhoto?

    private var addPhotoLabel: String {
        unit.photos.isEmpty ? "Add photo" : "Add another photo"
    }

    var body: some View {
        Section {
            if let cover = unit.coverPhoto {
                coverImage(cover)
            }

            PhotosPicker(selection: $pickerItem, matching: .images) {
                Label(addPhotoLabel, systemImage: "photo.badge.plus")
            }
            .accessibilityIdentifier("unitAddPhoto")

            if unit.photos.count > 1 {
                ForEach(unit.orderedPhotos) { photo in
                    photoRow(photo)
                }
            }
        } header: {
            Text("Photos")
        } footer: {
            if !unit.photos.isEmpty {
                Text("Photos are stored on this device. Tag stages automatically from your current painting state.")
            }
        }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task { await importPhoto(from: item) }
        }
        .confirmationDialog("Remove this photo?", isPresented: .init(
            get: { photoToDelete != nil },
            set: { if !$0 { photoToDelete = nil } }
        ), titleVisibility: .visible) {
            Button("Remove", role: .destructive) {
                if let photo = photoToDelete {
                    PhotoStore.delete(photo, in: context)
                    photoToDelete = nil
                }
            }
        }
    }

#if canImport(UIKit)
    @ViewBuilder
    private func coverImage(_ photo: ModelPhoto) -> some View {
        if let image = PhotoStore.loadImage(photo) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 280)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(alignment: .bottomLeading) {
                    StateChip(state: photo.stageKey, pipeline: pipeline)
                        .padding(8)
                }
                .accessibilityLabel("Cover photo, \(photo.stageKey)")
                .accessibilityIdentifier("unitCoverPhoto")
        }
    }

    @ViewBuilder
    private func photoRow(_ photo: ModelPhoto) -> some View {
        HStack(spacing: 12) {
            if let image = PhotoStore.loadImage(photo) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            VStack(alignment: .leading, spacing: 2) {
                StateChip(state: photo.stageKey, pipeline: pipeline)
                Text(photo.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if photo.isCover {
                Text("Cover")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
            } else {
                Button("Set cover") {
                    PhotoStore.setCover(photo, in: context)
                }
                .font(.caption)
            }
            Button(role: .destructive) {
                photoToDelete = photo
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Delete photo")
        }
    }
#endif

    private func importPhoto(from item: PhotosPickerItem) async {
        defer { pickerItem = nil }
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                banner.show("Could not read the selected image")
                return
            }
            _ = try PhotoStore.addPhoto(from: data, to: unit, stageKey: unit.state, in: context)
        } catch {
            banner.show(error.localizedDescription)
        }
    }
}

#if canImport(UIKit)
private struct PhotoThumb: View {
    let photo: ModelPhoto

    var body: some View {
        if let image = PhotoStore.loadImage(photo) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        }
    }
}
#endif

/// Small list-row thumbnail when a unit has a cover photo.
struct UnitPhotoThumb: View {
    let photo: ModelPhoto

    var body: some View {
#if canImport(UIKit)
        PhotoThumb(photo: photo)
            .frame(width: 44, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .accessibilityHidden(true)
#else
        EmptyView()
#endif
    }
}
