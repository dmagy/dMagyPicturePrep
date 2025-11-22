import SwiftUI
import AppKit
import Observation

// dMPP-2025-11-21-NAV2 — Folder navigation + crops + dMPMS sidecar read/write

struct DMPPImageEditorView: View {

    // [DMPP-SI-VM] Current image editor view model (optional until a folder is chosen)
    @State private var vm: DMPPImageEditorViewModel? = nil

    // [DMPP-SI-LIST] Folder + image list + current index
    @State private var folderURL: URL? = nil
    @State private var imageURLs: [URL] = []
    @State private var currentIndex: Int = 0

    var body: some View {

        VStack(spacing: 0) {

            // -----------------------------------------------------
            // [DMPP-SI-TOOLBAR] Top toolbar: folder + navigation + filename
            // -----------------------------------------------------
            HStack(spacing: 12) {

                Button("Choose Folder…") {
                    chooseFolder()
                }

                if let folderURL {
                    Text(folderURL.lastPathComponent)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Previous") {
                    goToPreviousImage()
                }
                .disabled(!canGoToPrevious)

                Button("Next") {
                    goToNextImage()
                }
                .disabled(!canGoToNext)

                Divider()

                Text(vm?.metadata.sourceFile ?? "No image selected")
                    .font(.headline.monospaced())
            }
            .padding()
            .background(.thinMaterial)

            Divider()

            // -----------------------------------------------------
            // [DMPP-SI-CONTENT] Main content: either placeholder or editor split view
            // -----------------------------------------------------
            if let vm {
                HStack(spacing: 0) {

                    // LEFT — Crops + Preview
                    DMPPCropEditorPane(vm: vm)
                        .frame(minWidth: 400)
                        .padding()
                        .background(Color(nsColor: .windowBackgroundColor))

                    Divider()

                    // RIGHT — Metadata Form
                    DMPPMetadataFormPane(vm: vm)
                        .frame(minWidth: 320, idealWidth: 360, maxWidth: 420)
                        .padding()
                }
            } else {
                // [DMPP-SI-EMPTY] Placeholder when no folder / image is selected
                VStack(spacing: 12) {
                    Text("Choose a folder to begin")
                        .font(.title2.weight(.semibold))
                    Text("dMagy Picture Prep will scan the folder for images and let you step through them with default crops.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: 420)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}


// MARK: - Left Pane

/// [DMPP-SI-LEFT] Crops + image preview + crop controls.
struct DMPPCropEditorPane: View {

    @Bindable var vm: DMPPImageEditorViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            Text("Crops")
                .font(.title3.bold())

            // [DMPP-SI-TABS] Tabs for each crop
            if vm.metadata.virtualCrops.isEmpty {
                Text("No crops defined. Use “New Crop” to add one.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                TabView(selection: $vm.selectedCropID) {
                    ForEach(vm.metadata.virtualCrops) { crop in
                        DMPPCropPreview(nsImage: vm.nsImage, crop: crop)
                            .tag(crop.id)
                            .tabItem { Text(crop.label) }
                    }
                }
                .tabViewStyle(.automatic)
            }

            // [DMPP-SI-CROP-BUTTONS] Crop control buttons (wired to VM)
            HStack(spacing: 8) {

                Menu("Select Crop") {
                    Button("Landscape 16:9") {
                        vm.addPresetCropLandscape()
                    }
                    Button("Portrait 8x10") {
                        vm.addPresetCropPortrait()
                    }
                    Button("Square 1:1") {
                        vm.addPresetCropSquare()
                    }
                }

                Button("New Crop") {
                    vm.newCrop()
                }

                Button("Duplicate") {
                    vm.duplicateSelectedCrop()
                }
                .disabled(vm.selectedCrop == nil)

                Button("Delete") {
                    vm.deleteSelectedCrop()
                }
                .disabled(vm.selectedCrop == nil)

                Spacer()
            }
        }
    }
}


// MARK: - Right Pane (Metadata)

struct DMPPMetadataFormPane: View {

    @Bindable var vm: DMPPImageEditorViewModel

    var body: some View {
        Form {

            Section("File") {
                Text(vm.metadata.sourceFile)
                    .font(.callout.monospaced())
            }

            Section("Description") {
                TextField("Title", text: $vm.metadata.title)
                TextField("Description", text: $vm.metadata.description, axis: .vertical)
                    .lineLimit(2...6)
            }

            Section("Date Taken") {
                TextField("YYYY, YYYY-MM, YYYY-MM-DD, or YYYYs",
                          text: $vm.metadata.dateTaken)
            }

            Section("Tags & People") {
                TextField(
                    "Tags",
                    text: Binding(
                        get: { vm.tagsText },
                        set: { vm.updateTags($0) }
                    )
                )

                TextField(
                    "People",
                    text: Binding(
                        get: { vm.peopleText },
                        set: { vm.updatePeople($0) }
                    )
                )
            }
        }
        .formStyle(.grouped)
    }
}


// MARK: - Image + Crop Preview

/// [DMPP-SI-PREVIEW] Real image preview with a crop overlay (non-interactive for now).
struct DMPPCropPreview: View {

    let nsImage: NSImage?
    let crop: VirtualCrop

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // [DMPP-PREVIEW-IMAGE] Actual image if available, fallback otherwise.
                if let nsImage {
                    Image(nsImage: nsImage)
                        .resizable()
                        .scaledToFit()
                } else {
                    Rectangle()
                        .fill(.secondary.opacity(0.2))
                        .overlay(
                            Text("Image not available")
                                .foregroundStyle(.secondary)
                        )
                }

                // [DMPP-PREVIEW-CROP] Rough visualization of crop rect.
                let w = geo.size.width * crop.rect.width
                let h = geo.size.height * crop.rect.height
                let x = geo.size.width * crop.rect.x
                let y = geo.size.height * crop.rect.y

                Rectangle()
                    .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: w, height: h)
                    .position(x: x + w / 2, y: y + h / 2)
            }
        }
        .aspectRatio(16.0 / 9.0, contentMode: .fit) // working default
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .padding()
    }
}


// MARK: - Navigation + Sidecar Helpers

extension DMPPImageEditorView {

    // [DMPP-NAV-CAN-GO] Computed flags for Previous/Next buttons
    private var canGoToPrevious: Bool {
        imageURLs.indices.contains(currentIndex - 1)
    }

    private var canGoToNext: Bool {
        imageURLs.indices.contains(currentIndex + 1)
    }

    // [DMPP-NAV-FOLDER] Show NSOpenPanel to choose a folder
    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"

        if panel.runModal() == .OK, let url = panel.url {
            loadImages(from: url)
        }
    }

    // [DMPP-NAV-LOAD-FOLDER] Scan folder for supported image types
    private func loadImages(from folder: URL) {
        // Save current image metadata before switching folders
        saveCurrentMetadata()

        folderURL = folder

        let fm = FileManager.default
        let keys: [URLResourceKey] = [.isRegularFileKey, .typeIdentifierKey]

        let urls = (try? fm.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
        )) ?? []

        imageURLs = urls.filter { isSupportedImageURL($0) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        if imageURLs.isEmpty {
            vm = nil
            currentIndex = 0
        } else {
            loadImage(at: 0)
        }
    }

    // [DMPP-NAV-SUPPORTED] Basic extension filter for images
    private func isSupportedImageURL(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return ["jpg", "jpeg", "png", "heic", "tif", "tiff", "webp"].contains(ext)
    }

    // [DMPP-NAV-LOAD-IMAGE] Save current, then create a fresh VM for the image at index
    private func loadImage(at index: Int) {
        guard imageURLs.indices.contains(index) else { return }

        // Save the metadata for the current image before switching
        saveCurrentMetadata()

        currentIndex = index
        let url = imageURLs[index]

        // Load metadata from sidecar if present, otherwise defaults
        let metadata = loadMetadata(for: url)
        vm = DMPPImageEditorViewModel(imageURL: url, metadata: metadata)
    }

    // [DMPP-NAV-NEXT/PREV]
    private func goToPreviousImage() {
        let newIndex = currentIndex - 1
        guard imageURLs.indices.contains(newIndex) else { return }
        loadImage(at: newIndex)
    }

    private func goToNextImage() {
        let newIndex = currentIndex + 1
        guard imageURLs.indices.contains(newIndex) else { return }
        loadImage(at: newIndex)
    }

    // ============================================================
    // [DMPP-SIDECAR] dMPMS sidecar read/write
    // ============================================================

    /// [DMPP-SIDECAR-URL] Sidecar path: <filename>.<image_ext>.dmpms.json
    private func sidecarURL(for imageURL: URL) -> URL {
        imageURL.appendingPathExtension("dmpms.json")
    }

    /// [DMPP-SIDECAR-SAVE] Save current VM metadata to a sidecar file, if any.
    private func saveCurrentMetadata() {
        guard let vm else {
            print("dMPP: saveCurrentMetadata() — no VM, nothing to save")
            return
        }

        let metadata = vm.metadata
        let url = sidecarURL(for: vm.imageURL)

        print("dMPP: Attempting to save metadata for \(metadata.sourceFile) to:")
        print("      \(url.path)")

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(metadata)
            try data.write(to: url, options: .atomic)

            print("dMPP: ✅ Saved metadata successfully.")
        } catch {
            let nsError = error as NSError
            print("dMPP: ❌ Failed to save metadata for \(metadata.sourceFile)")
            print("      Domain: \(nsError.domain)")
            print("      Code:   \(nsError.code)")
            print("      Desc:   \(nsError.localizedDescription)")
        }
    }



    /// [DMPP-SIDECAR-LOAD] Load metadata from sidecar if present; else defaults.
    private func loadMetadata(for imageURL: URL) -> DmpmsMetadata {
        let sidecar = sidecarURL(for: imageURL)
        let fm = FileManager.default

        if fm.fileExists(atPath: sidecar.path) {
            do {
                let data = try Data(contentsOf: sidecar)
                var metadata = try JSONDecoder().decode(DmpmsMetadata.self, from: data)

                // Ensure sourceFile matches the actual image filename
                metadata.sourceFile = imageURL.lastPathComponent
                return metadata
            } catch {
                print("dMPP: Failed to read metadata from \(sidecar.lastPathComponent): \(error)")
                return makeDefaultMetadata(for: imageURL)
            }
        } else {
            return makeDefaultMetadata(for: imageURL)
        }
    }

    // [DMPP-NAV-DEFAULT-META] Default dMPMS metadata for a new image
    private func makeDefaultMetadata(for url: URL) -> DmpmsMetadata {
        let filename = url.lastPathComponent

        return DmpmsMetadata(
            dmpmsVersion: "1.0",
            sourceFile: filename,
            title: "",
            description: "",
            dateTaken: "",
            tags: [],
            people: [],
            virtualCrops: defaultVirtualCrops(),
            history: []
        )
    }

    // [DMPP-NAV-DEFAULT-CROPS] Default 16:9 + 8x10 crops
    private func defaultVirtualCrops() -> [VirtualCrop] {
        [
            VirtualCrop(
                id: "crop-16x9-default",
                label: "Landscape 16:9",
                aspectRatio: "16:9",
                rect: RectNormalized(x: 0.0, y: 0.1, width: 1.0, height: 0.8)
            ),
            VirtualCrop(
                id: "crop-8x10-default",
                label: "Portrait 8x10",
                aspectRatio: "8:10",
                rect: RectNormalized(x: 0.15, y: 0.0, width: 0.7, height: 1.0)
            )
        ]
    }
}


#Preview {
    DMPPImageEditorView()
        .frame(width: 1000, height: 650)
}
