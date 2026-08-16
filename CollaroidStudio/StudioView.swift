import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct StudioView: View {
    @EnvironmentObject private var model: StudioModel
    @State private var isDropTarget = false
    @AppStorage("isInspectorPresented") private var isInspectorPresented = true
    @AppStorage("photoBrowserIsVisible") private var photoBrowserIsVisible = true

    var body: some View {
        workspace
            .background(Color(nsColor: .windowBackgroundColor))
            .navigationTitle("Collaroid Studio")
            .inspector(isPresented: $isInspectorPresented) {
                inspector
                    .inspectorColumnWidth(min: 310, ideal: 340, max: 400)
            }
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: $isDropTarget, perform: handleDrop)
        .alert("Collaroid Studio", isPresented: Binding(
            get: { model.presentedError != nil },
            set: { if !$0 { model.presentedError = nil } }
        )) {
            Button("OK", role: .cancel) { model.presentedError = nil }
        } message: {
            Text(model.presentedError ?? "Unknown error")
        }
    }

    @ViewBuilder
    private var workspace: some View {
        if model.photoBrowserPosition == .left {
            NavigationSplitView(columnVisibility: photoBrowserColumnVisibility) {
                FolderFilmstrip(position: .left)
                    .environmentObject(model)
                    .navigationSplitViewColumnWidth(min: 164, ideal: 184, max: 230)
            } detail: {
                canvas
            }
            .navigationSplitViewStyle(.balanced)
        } else {
            VStack(spacing: 16) {
                canvas

                FolderFilmstrip(position: .bottom)
                    .environmentObject(model)
                    .frame(height: 146)
                    .padding(.horizontal, 28)
                    .padding(.bottom, 22)
            }
        }
    }

    private var canvas: some View {
        ZStack(alignment: .topTrailing) {
            PrintPreview(isDropTarget: isDropTarget)
                .environmentObject(model)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            dogNumberBadge
                .padding(16)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 22)
        .toolbar { trailingToolbar }
    }

    private var photoBrowserColumnVisibility: Binding<NavigationSplitViewVisibility> {
        Binding(
            get: { photoBrowserIsVisible ? .all : .detailOnly },
            set: { photoBrowserIsVisible = $0 != .detailOnly }
        )
    }

    @ViewBuilder
    private var dogNumberBadge: some View {
        let badge = Text(model.dogNumberText)
            .font(.headline.monospacedDigit())
            .padding(.horizontal, 12)
            .padding(.vertical, 7)

        if #available(macOS 26.0, *) {
            badge.glassEffect(.regular, in: .capsule)
        } else {
            badge.background(.regularMaterial, in: Capsule())
        }
    }

    @ToolbarContentBuilder
    private var trailingToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button(action: model.choosePhoto) {
                Image(systemName: "photo.badge.plus")
            }
            .accessibilityLabel("Add Photo")
            .help("Add Photo…")

            Button(action: model.printCurrent) {
                Image(systemName: "printer")
            }
            .accessibilityLabel("Print")
            .disabled(!model.hasPhoto || model.isWorking)
            .help("Print")

            Button(action: model.exportAndNext) {
                Image(systemName: "square.and.arrow.down")
            }
            .accessibilityLabel("Export & Next")
            .disabled(!model.hasPhoto || model.isWorking)
            .help("Export & Next")

            SettingsLink {
                Image(systemName: "gearshape")
            }
            .accessibilityLabel("Settings")
            .help("Settings")

            Button {
                isInspectorPresented.toggle()
            } label: {
                Image(systemName: "sidebar.trailing")
            }
            .accessibilityLabel(isInspectorPresented ? "Hide Inspector" : "Show Inspector")
            .help(isInspectorPresented ? "Hide Inspector" : "Show Inspector")
        }
    }

    private var inspector: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Label("Inspector", systemImage: "slider.horizontal.3")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, 8)

            controls
                .padding(.horizontal, 8)
                .padding(.bottom, 12)
        }
    }

    private var controls: some View {
        Form {
            Section("Photo") {
                Button(action: model.choosePhoto) {
                    Label("Add Photo…", systemImage: "photo.badge.plus")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            Section("Crop") {
                ControlGroup {
                    Button(action: model.zoomOut) {
                        Label("Zoom Out", systemImage: "minus.magnifyingglass")
                    }
                    Button(action: model.zoomIn) {
                        Label("Zoom In", systemImage: "plus.magnifyingglass")
                    }
                }
                .disabled(!model.hasPhoto)

                LabeledContent("Zoom") {
                    Text("\(Int((model.crop.zoom * 100).rounded()))%")
                        .monospacedDigit()
                }

                Button(action: model.resetCrop) {
                    Label("Reset Crop", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .disabled(!model.hasPhoto)

                Text("Pinch or scroll over the preview to zoom. Drag to reposition.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Adjustments") {
                adjustmentSlider(
                    "Shadows",
                    systemImage: "circle.lefthalf.filled",
                    value: $model.adjustments.shadows,
                    range: -100...100
                )
                adjustmentSlider(
                    "Highlights",
                    systemImage: "sun.max",
                    value: $model.adjustments.highlights,
                    range: -100...100
                )
                adjustmentSlider(
                    "Saturation",
                    systemImage: "drop.fill",
                    value: $model.adjustments.saturation,
                    range: -100...100
                )
                adjustmentSlider(
                    "Warmth",
                    systemImage: "thermometer.medium",
                    value: $model.adjustments.warmth,
                    range: -100...100
                )

                Button(action: model.resetAdjustments) {
                    Label("Reset Adjustments", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .disabled(!model.hasPhoto || !model.hasAdjustments)
            }
            .disabled(!model.hasPhoto)

            Section("Layout") {
                Toggle(isOn: Binding(
                    get: { model.includeBorder },
                    set: model.setIncludeBorder
                )) {
                    Label("Border & Branding", systemImage: "rectangle.inset.filled")
                }

                Text(model.includeBorder
                     ? "Adds the white border and Collaroid event branding."
                     : "Prints and exports the photo edge-to-edge without branding.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Output") {
                Button(action: model.printCurrent) {
                    Label("Print", systemImage: "printer")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .disabled(!model.hasPhoto || model.isWorking)

                exportButton
            }

            Section {
                LabeledContent {
                    Text(model.statusMessage)
                        .lineLimit(2)
                        .truncationMode(.middle)
                } label: {
                    Label("Status", systemImage: model.watchFolder == nil ? "photo" : "folder")
                }

                LabeledContent("Format", value: "JPEG")
                LabeledContent("Size", value: "1181 × 1748 px")
                LabeledContent("Resolution", value: "300 DPI")
            }
        }
        .formStyle(.grouped)
    }

    private func adjustmentSlider(
        _ title: String,
        systemImage: String,
        value: Binding<Double>,
        range: ClosedRange<Double>
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(title, systemImage: systemImage)
                Spacer()
                Text("\(Int(value.wrappedValue.rounded()))")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .frame(minWidth: 34, alignment: .trailing)
            }
            Slider(value: value, in: range, step: 1)
        }
    }

    @ViewBuilder
    private var exportButton: some View {
        let button = Button(action: model.exportAndNext) {
            HStack {
                if model.isWorking {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: "square.and.arrow.down")
                }
                Text("Export & Next")
                Spacer()
                Text("↵")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .controlSize(.large)
        .disabled(!model.hasPhoto || model.isWorking)

        if #available(macOS 26.0, *) {
            button.buttonStyle(.glassProminent)
        } else {
            button.buttonStyle(.borderedProminent)
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }) else {
            return false
        }
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            let url: URL?
            if let data = item as? Data {
                url = URL(dataRepresentation: data, relativeTo: nil)
            } else {
                url = item as? URL
            }
            guard let url else { return }
            Task { @MainActor in model.loadPhoto(from: url) }
        }
        return true
    }
}

private struct FolderFilmstrip: View {
    @EnvironmentObject private var model: StudioModel
    let position: PhotoBrowserPosition

    @ViewBuilder
    var body: some View {
        if position == .left {
            browserContent
                .padding(.horizontal, 14)
                .padding(.top, 16)
                .padding(.bottom, 14)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            browserContent
                .padding(12)
                .modifier(NavigationSurface())
        }
    }

    private var browserContent: some View {
        VStack(spacing: 10) {
            browserHeader

            if model.watchFolder == nil {
                Group {
                    Text("Open a folder to browse its photos here.")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button(position == .left ? "OPEN FOLDER" : "OPEN PHOTO FOLDER", action: model.chooseWatchFolder)
                        .controlSize(.small)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if model.folderPhotos.isEmpty && !model.isRefreshingFolder {
                Text("NO JPG OR PNG PHOTOS IN THIS FOLDER")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.1)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                thumbnails
            }
        }
    }

    @ViewBuilder
    private var browserHeader: some View {
        if position == .left {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "folder.fill")
                        .foregroundStyle(.tint)
                    Text(model.watchFolder?.lastPathComponent ?? "Photo Folder")
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    if model.isRefreshingFolder {
                        ProgressView().controlSize(.small)
                    }
                }

                HStack(spacing: 4) {
                    if let index = model.selectedFolderPhotoIndex {
                        Text("\(index + 1)/\(model.folderPhotos.count)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    } else {
                        Text("\(model.folderPhotos.count) photos")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    previousButton
                    nextButton
                    refreshButton
                }
            }
            .foregroundStyle(.secondary)
        } else {
            HStack(spacing: 8) {
                Image(systemName: "folder.fill")
                    .foregroundStyle(.tint)
                Text(model.folderStatusText)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)

                if model.isRefreshingFolder {
                    ProgressView().controlSize(.small)
                }

                Spacer()

                if let index = model.selectedFolderPhotoIndex {
                    Text("\(index + 1) / \(model.folderPhotos.count)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                previousButton
                nextButton
                refreshButton
            }
            .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var thumbnails: some View {
        ScrollViewReader { proxy in
            if position == .left {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 9) {
                        thumbnailItems(width: 128, height: 88)
                    }
                }
                .onAppear { scrollToSelection(proxy, animated: false) }
                .onChange(of: model.selectedFolderPhotoID) { _, _ in
                    scrollToSelection(proxy, animated: true)
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 9) {
                        thumbnailItems(width: 82, height: 72)
                    }
                }
                .onAppear { scrollToSelection(proxy, animated: false) }
                .onChange(of: model.selectedFolderPhotoID) { _, _ in
                    scrollToSelection(proxy, animated: true)
                }
            }
        }
    }

    @ViewBuilder
    private func thumbnailItems(width: CGFloat, height: CGFloat) -> some View {
        ForEach(model.folderPhotos) { item in
            FolderThumbnail(
                item: item,
                isSelected: item.id == model.selectedFolderPhotoID,
                width: width,
                height: height,
                action: { model.selectFolderPhoto(item) }
            )
            .id(item.id)
        }
    }

    private var previousButton: some View {
        navigationButton(
            systemName: "chevron.left",
            help: "Previous photo",
            disabled: !model.canSelectPreviousFolderPhoto,
            action: model.selectPreviousFolderPhoto
        )
    }

    private var nextButton: some View {
        navigationButton(
            systemName: "chevron.right",
            help: "Next photo",
            disabled: !model.canSelectNextFolderPhoto,
            action: model.selectNextFolderPhoto
        )
    }

    private var refreshButton: some View {
        navigationButton(
            systemName: "arrow.clockwise",
            help: "Refresh folder",
            disabled: model.watchFolder == nil || model.isRefreshingFolder,
            action: { model.refreshFolder() }
        )
    }

    private func scrollToSelection(_ proxy: ScrollViewProxy, animated: Bool) {
        guard let selectedID = model.selectedFolderPhotoID else { return }
        if animated {
            withAnimation(.easeOut(duration: 0.18)) {
                proxy.scrollTo(selectedID, anchor: .center)
            }
        } else {
            proxy.scrollTo(selectedID, anchor: .center)
        }
    }

    private func navigationButton(
        systemName: String,
        help: String,
        disabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .frame(width: 20, height: 20)
        }
        .buttonStyle(.borderless)
        .disabled(disabled)
        .help(help)
    }
}

private struct FolderThumbnail: View {
    let item: FolderPhotoItem
    let isSelected: Bool
    let width: CGFloat
    let height: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Image(nsImage: item.thumbnail)
                    .resizable()
                    .scaledToFill()
                    .frame(width: width, height: height)
                    .clipped()

                if item.isExported {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .green)
                        .padding(5)
                }
            }
            .frame(width: width, height: height)
            .background(.quaternary)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.18), lineWidth: isSelected ? 3 : 1)
            )
        }
        .buttonStyle(.plain)
        .help(item.isExported ? "\(item.filename) — Exported" : item.filename)
        .accessibilityLabel(item.filename)
        .accessibilityValue(item.isExported ? "Exported" : "Not exported")
    }
}

private struct PrintPreview: View {
    @EnvironmentObject private var model: StudioModel
    @State private var magnificationStartZoom: CGFloat?
    let isDropTarget: Bool

    var body: some View {
        GeometryReader { outer in
            let availableHeight = outer.size.height
            let availableWidth = outer.size.width
            let ratio = PrintTemplate.pixelSize.width / PrintTemplate.pixelSize.height
            let height = min(availableHeight, availableWidth / ratio)
            let width = height * ratio

            ZStack {
                Color.clear
                card(size: CGSize(width: width, height: height))
                    .frame(width: width, height: height)
                    .shadow(color: .black.opacity(0.45), radius: 22, y: 12)
                    .overlay {
                        if isDropTarget {
                            RoundedRectangle(cornerRadius: 3)
                                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 5, dash: [12, 7]))
                                .background(Color.accentColor.opacity(0.12))
                        }
                    }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func card(size: CGSize) -> some View {
        let scale = size.width / PrintTemplate.pixelSize.width
        let photoRect = PrintTemplate.photoRect(includeBorder: model.includeBorder)
        let photoSize = CGSize(
            width: photoRect.width * scale,
            height: photoRect.height * scale
        )
        return ZStack(alignment: .topLeading) {
            Color.white

            photoArea(size: photoSize)
                .frame(width: photoSize.width, height: photoSize.height)
                .clipped()
                .position(
                    x: photoRect.midX * scale,
                    y: photoRect.midY * scale
                )

            if model.includeBorder {
                branding(scale: scale, cardSize: size)
            }
        }
        .frame(width: size.width, height: size.height)
        .clipped()
    }

    @ViewBuilder
    private func photoArea(size: CGSize) -> some View {
        if let photo = model.photo {
            GeometryReader { geo in
                let previewImage = model.adjustedPreviewImage ?? photo.previewImage
                let cover = max(geo.size.width / previewImage.size.width,
                                geo.size.height / previewImage.size.height)
                let renderedWidth = previewImage.size.width * cover * model.crop.zoom
                let renderedHeight = previewImage.size.height * cover * model.crop.zoom
                let travelX = max(0, (renderedWidth - geo.size.width) / 2)
                let travelY = max(0, (renderedHeight - geo.size.height) / 2)

                ZStack {
                    Image(nsImage: previewImage)
                        .resizable()
                        .frame(width: renderedWidth, height: renderedHeight)
                        .position(x: geo.size.width / 2, y: geo.size.height / 2)
                        .offset(
                            x: model.crop.pan.width * travelX,
                            y: model.crop.pan.height * travelY
                        )
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if value.translation == .zero { model.beginDrag() }
                            model.updateDrag(translation: value.translation, previewSize: geo.size)
                        }
                )
                .simultaneousGesture(
                    MagnificationGesture()
                        .onChanged { magnification in
                            if magnificationStartZoom == nil {
                                magnificationStartZoom = model.crop.zoom
                            }
                            model.setZoom((magnificationStartZoom ?? model.crop.zoom) * magnification)
                        }
                        .onEnded { _ in
                            magnificationStartZoom = nil
                        }
                )
                .background {
                    PreviewScrollWheelMonitor { delta, isPrecise in
                        model.zoom(withScrollDelta: delta, isPrecise: isPrecise)
                    }
                }
            }
        } else {
            ZStack {
                Color(red: 0.93, green: 0.93, blue: 0.92)
                VStack(spacing: 10) {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 32, weight: .regular))
                        .foregroundStyle(Color.accentColor)
                    Text("Drop a Photo")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color.black.opacity(0.74))
                    Text("JPG or PNG")
                        .font(.caption)
                        .foregroundStyle(Color.black.opacity(0.42))
                }
            }
        }
    }

    private func branding(scale: CGFloat, cardSize: CGSize) -> some View {
        ZStack(alignment: .topLeading) {
            if let logo = BrandAssets.logo, logo.size.width > 1 {
                Image(nsImage: logo)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 540 * scale, height: 120 * scale)
                    .position(
                        x: cardSize.width / 2,
                        y: cardSize.height - (115 + 60) * scale
                    )
            } else {
                Text("OFFICIAL LOGO REQUIRED")
                    .font(.system(size: max(7, 24 * scale), weight: .semibold))
                    .tracking(max(0.5, 2 * scale))
                    .foregroundStyle(Color.accentColor)
                    .position(
                        x: cardSize.width / 2,
                        y: cardSize.height - (115 + 60) * scale
                    )
            }
            Text("DOG FEST 2026")
                .font(.system(size: max(8, 32 * scale), weight: .medium))
                .tracking(max(1, 7.5 * scale))
                .foregroundStyle(Color.black.opacity(0.78))
                .position(
                    x: cardSize.width / 2,
                    y: cardSize.height - 68 * scale
                )
        }
        .frame(width: cardSize.width, height: cardSize.height)
    }
}

private struct PreviewScrollWheelMonitor: NSViewRepresentable {
    let onScroll: (CGFloat, Bool) -> Void

    func makeNSView(context: Context) -> MonitorView {
        let view = MonitorView()
        view.onScroll = onScroll
        return view
    }

    func updateNSView(_ nsView: MonitorView, context: Context) {
        nsView.onScroll = onScroll
    }

    static func dismantleNSView(_ nsView: MonitorView, coordinator: ()) {
        nsView.removeMonitor()
    }

    final class MonitorView: NSView {
        var onScroll: ((CGFloat, Bool) -> Void)?
        private var eventMonitor: Any?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            removeMonitor()
            guard window != nil else { return }

            eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                guard let self,
                      let window = self.window,
                      NSApp.isActive,
                      window.isKeyWindow else {
                    return event
                }

                let windowPoint = window.convertPoint(fromScreen: NSEvent.mouseLocation)
                let localPoint = self.convert(windowPoint, from: nil)
                guard self.bounds.contains(localPoint) else { return event }

                self.onScroll?(event.scrollingDeltaY, event.hasPreciseScrollingDeltas)
                return nil
            }
        }

        func removeMonitor() {
            guard let eventMonitor else { return }
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
        }

        deinit {
            removeMonitor()
        }
    }
}

private struct NavigationSurface: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content.glassEffect(.regular, in: .rect(cornerRadius: 18))
        } else {
            content.background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
        }
    }
}
