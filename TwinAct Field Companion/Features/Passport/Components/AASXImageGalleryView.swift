//
//  AASXImageGalleryView.swift
//  TwinAct Field Companion
//
//  Image gallery view for displaying extracted AASX images in a grid layout
//  with category filtering and full-screen viewing support.
//

import SwiftUI

// MARK: - Image Gallery View

/// Grid gallery of images extracted from AASX packages.
/// Supports filtering by category and full-screen viewing.
public struct AASXImageGalleryView: View {

    // MARK: - Properties

    let assetId: String
    @State private var images: [AASXImageItem] = []
    @State private var selectedCategory: AASXImageCategory?
    @State private var selectedImage: AASXImageItem?
    @State private var isExpanded: Bool = true

    private let columns = [
        GridItem(.adaptive(minimum: 80, maximum: 120), spacing: 12)
    ]

    // MARK: - Body

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerView

            if isExpanded && !images.isEmpty {
                Divider()
                    .padding(.horizontal)

                contentView
                    .padding()
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
        .onAppear {
            loadImages()
        }
        .fullScreenCover(item: $selectedImage) { image in
            ImageViewerOverlay(
                image: image,
                allImages: filteredImages,
                onDismiss: { selectedImage = nil }
            )
        }
    }

    // MARK: - Header View

    private var headerView: some View {
        Button {
            withAnimation {
                isExpanded.toggle()
            }
        } label: {
            HStack {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.title3)
                    .foregroundColor(.teal)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Images")
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text("\(images.count) image\(images.count == 1 ? "" : "s") available")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
        .buttonStyle(.plain)
    }

    // MARK: - Content View

    private var contentView: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Category filter chips
            if uniqueCategories.count > 1 {
                categoryFilterView
            }

            // Image grid
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(filteredImages) { image in
                    ImageThumbnailView(image: image)
                        .onTapGesture {
                            selectedImage = image
                        }
                }
            }

            // Empty state for filter
            if filteredImages.isEmpty && !images.isEmpty {
                Text("No images in this category")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            }
        }
    }

    // MARK: - Category Filter

    private var categoryFilterView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                CategoryChip(
                    title: "All",
                    isSelected: selectedCategory == nil,
                    count: images.count
                ) {
                    selectedCategory = nil
                }

                ForEach(uniqueCategories, id: \.self) { category in
                    let count = images.filter { $0.category == category }.count
                    CategoryChip(
                        title: category.displayName,
                        isSelected: selectedCategory == category,
                        count: count
                    ) {
                        selectedCategory = category
                    }
                }
            }
        }
    }

    // MARK: - Computed Properties

    private var filteredImages: [AASXImageItem] {
        if let category = selectedCategory {
            return images.filter { $0.category == category }
        }
        return images
    }

    private var uniqueCategories: [AASXImageCategory] {
        Array(Set(images.map(\.category))).sorted { $0.displayName < $1.displayName }
    }

    // MARK: - Private Methods

    private func loadImages() {
        images = AASXContentStore.shared.images(for: assetId)
    }
}

// MARK: - Category Chip

/// Filter chip for image categories.
private struct CategoryChip: View {
    let title: String
    let isSelected: Bool
    let count: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.caption)

                Text("(\(count))")
                    .font(.caption2)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? Color.accentColor : Color(.tertiarySystemBackground))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Image Thumbnail View

/// Thumbnail cell for the image grid.
private struct ImageThumbnailView: View {
    let image: AASXImageItem

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            AsyncImage(url: image.url) { phase in
                switch phase {
                case .success(let loadedImage):
                    loadedImage
                        .resizable()
                        .aspectRatio(contentMode: .fill)

                case .failure:
                    placeholder(icon: "exclamationmark.triangle")

                case .empty:
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(.tertiarySystemBackground))

                @unknown default:
                    placeholder(icon: "photo")
                }
            }
            .frame(width: 80, height: 80)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Category badge
            Image(systemName: image.category.icon)
                .font(.caption2)
                .foregroundColor(.white)
                .padding(4)
                .background(categoryColor.opacity(0.9))
                .clipShape(Circle())
                .offset(x: 4, y: 4)
        }
        .accessibilityLabel("\(image.category.displayName) image: \(image.filename)")
    }

    private func placeholder(icon: String) -> some View {
        ZStack {
            Color(.tertiarySystemBackground)

            Image(systemName: icon)
                .foregroundColor(.secondary)
        }
        .frame(width: 80, height: 80)
    }

    private var categoryColor: Color {
        switch image.category {
        case .product: return .blue
        case .certification: return .green
        case .logo: return .purple
        case .thumbnail: return .orange
        case .other: return .gray
        }
    }
}

// MARK: - Image Viewer Overlay

/// Full-screen image viewer with swipe navigation.
private struct ImageViewerOverlay: View {
    let image: AASXImageItem
    let allImages: [AASXImageItem]
    let onDismiss: () -> Void

    @State private var currentIndex: Int = 0
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @GestureState private var dragOffset: CGSize = .zero

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                TabView(selection: $currentIndex) {
                    ForEach(Array(allImages.enumerated()), id: \.element.id) { index, img in
                        ZoomableImageContainer(url: img.url)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .automatic))
            }
            .navigationTitle(currentImage.filename)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        onDismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: currentImage.url) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
            .onAppear {
                if let index = allImages.firstIndex(where: { $0.id == image.id }) {
                    currentIndex = index
                }
            }
        }
    }

    private var currentImage: AASXImageItem {
        guard currentIndex >= 0 && currentIndex < allImages.count else {
            return image
        }
        return allImages[currentIndex]
    }
}

// MARK: - Zoomable Image Container

/// Container that enables pinch-to-zoom and pan gestures.
private struct ZoomableImageContainer: View {
    let url: URL
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        GeometryReader { geometry in
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(scale)
                        .offset(x: offset.width, y: offset.height)
                        .gesture(magnificationGesture)
                        .gesture(dragGesture)
                        .onTapGesture(count: 2) {
                            withAnimation(.spring()) {
                                if scale > 1 {
                                    scale = 1
                                    offset = .zero
                                } else {
                                    scale = 2
                                }
                                lastScale = scale
                                lastOffset = offset
                            }
                        }

                case .failure:
                    ContentUnavailableView(
                        "Unable to Load",
                        systemImage: "exclamationmark.triangle",
                        description: Text("The image could not be loaded")
                    )

                case .empty:
                    ProgressView()
                        .scaleEffect(1.5)

                @unknown default:
                    EmptyView()
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let delta = value / lastScale
                lastScale = value
                scale = min(max(scale * delta, 1), 4)
            }
            .onEnded { _ in
                lastScale = 1.0
                if scale < 1 {
                    withAnimation(.spring()) {
                        scale = 1
                        offset = .zero
                    }
                }
            }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if scale > 1 {
                    offset = CGSize(
                        width: lastOffset.width + value.translation.width,
                        height: lastOffset.height + value.translation.height
                    )
                }
            }
            .onEnded { _ in
                lastOffset = offset
            }
    }
}

// MARK: - Preview Provider

#if DEBUG
struct AASXImageGalleryView_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack(spacing: 20) {
                AASXImageGalleryView(assetId: "preview-asset")
            }
            .padding()
        }
    }
}
#endif
