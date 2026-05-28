import SwiftUI
import PhotosUI

/// Horizontal photo strip for a contact. Mirrors the web frontend's
/// `PhotoGallery.tsx`: the primary photo is rendered first with a star badge,
/// followed by the rest sorted by `sort_order`. When `editable` is true,
/// a trailing "+" tile opens `PhotosPicker` for multi-select, and each tile
/// has a context menu with "Make primary" / "Delete".
struct PhotoGalleryView: View {
    let personId: String
    var editable: Bool = false
    /// Called after any mutation that may have changed `Person.avatar_url`,
    /// so the parent detail screen can refresh the rest of its data.
    var onPrimaryChanged: (() -> Void)? = nil

    @State private var photos: [PersonPhoto] = []
    @State private var isLoading = false
    @State private var isUploading = false
    @State private var errorMessage: String?
    @State private var pickerItems: [PhotosPickerItem] = []

    private let indigo = Color(red: 0.31, green: 0.27, blue: 0.90)
    private let api = APIClient.shared
    private let tileSize: CGFloat = 80

    /// Primary first, then the rest in their declared `sort_order`.
    private var sortedPhotos: [PersonPhoto] {
        photos.sorted { a, b in
            if a.isPrimary != b.isPrimary { return a.isPrimary && !b.isPrimary }
            return a.sortOrder < b.sortOrder
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(sortedPhotos) { photo in
                        photoTile(photo)
                    }
                    if editable {
                        addTile
                    }
                }
                .padding(.horizontal, 16)
            }

            if let errorMessage {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundColor(.red)
                    Text(errorMessage)
                        .font(.caption2)
                        .foregroundColor(.red)
                    Spacer()
                    Button {
                        self.errorMessage = nil
                    } label: {
                        Image(systemName: "xmark").font(.caption2)
                    }
                    .buttonStyle(.borderless)
                }
                .padding(.horizontal, 16)
            }
        }
        .task(id: personId) { await load() }
        .onChange(of: pickerItems) { _, items in
            guard !items.isEmpty else { return }
            Task { await handlePicked(items) }
        }
    }

    // MARK: - Tiles

    @ViewBuilder
    private func photoTile(_ photo: PersonPhoto) -> some View {
        let resolved = api.absoluteURL(forAsset: photo.url)
        ZStack(alignment: .topLeading) {
            AsyncImage(url: resolved) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    ZStack {
                        Color(.systemGray5)
                        Image(systemName: "photo")
                            .foregroundColor(.secondary)
                    }
                case .empty:
                    ZStack {
                        Color(.systemGray6)
                        ProgressView().scaleEffect(0.7)
                    }
                @unknown default:
                    Color(.systemGray6)
                }
            }
            .frame(width: tileSize, height: tileSize)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(photo.isPrimary ? indigo : Color(.systemGray4),
                            lineWidth: photo.isPrimary ? 2 : 0.5)
            )

            if photo.isPrimary {
                Image(systemName: "star.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(4)
                    .background(Circle().fill(indigo))
                    .offset(x: -4, y: -4)
                    .accessibilityLabel("Primary photo")
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 10))
        .contextMenu {
            if editable {
                if !photo.isPrimary {
                    Button {
                        Task { await setPrimary(photo) }
                    } label: {
                        Label("Make primary", systemImage: "star")
                    }
                }
                Button(role: .destructive) {
                    Task { await delete(photo) }
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }

    private var addTile: some View {
        PhotosPicker(
            selection: $pickerItems,
            maxSelectionCount: 0,                 // 0 = unlimited
            matching: .images,
            photoLibrary: .shared()
        ) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                    .foregroundColor(Color(.systemGray3))
                VStack(spacing: 4) {
                    if isUploading {
                        ProgressView().scaleEffect(0.8)
                    } else {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(indigo)
                    }
                    Text(isUploading ? "Uploading" : "Add")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: tileSize, height: tileSize)
        }
        .disabled(isUploading)
        .accessibilityLabel("Add photos")
    }

    // MARK: - Data

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            photos = try await api.listPhotos(personId: personId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func handlePicked(_ items: [PhotosPickerItem]) async {
        // Snapshot then clear immediately so subsequent picks fire again.
        let snapshot = items
        pickerItems = []

        isUploading = true
        defer { isUploading = false }
        errorMessage = nil

        for item in snapshot {
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else { continue }
                // Re-encode to JPEG at ~0.85 quality to keep payloads small
                // and side-step HEIC/PNG support quirks on the backend.
                let jpeg: Data
                if let img = UIImage(data: data),
                   let encoded = img.jpegData(compressionQuality: 0.85) {
                    jpeg = encoded
                } else {
                    jpeg = data
                }
                let uploaded = try await api.uploadPhoto(
                    personId: personId,
                    imageData: jpeg,
                    mimeType: "image/jpeg",
                    source: "manual_upload"
                )
                photos.append(uploaded)
                // If the new photo became primary (e.g. first photo for a
                // person), notify the parent so the cached avatar refreshes.
                if uploaded.isPrimary {
                    onPrimaryChanged?()
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func setPrimary(_ photo: PersonPhoto) async {
        do {
            _ = try await api.setPrimaryPhoto(personId: personId, photoId: photo.id)
            // Reload to pick up the server's freshly normalised flags.
            await load()
            onPrimaryChanged?()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func delete(_ photo: PersonPhoto) async {
        do {
            try await api.deletePhoto(personId: personId, photoId: photo.id)
            photos.removeAll { $0.id == photo.id }
            // Deleting the primary may have promoted a different photo
            // server-side, so refresh to stay in sync.
            if photo.isPrimary {
                await load()
                onPrimaryChanged?()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
