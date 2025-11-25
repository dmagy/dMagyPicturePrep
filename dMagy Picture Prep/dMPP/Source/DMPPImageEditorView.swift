import SwiftUI
import AppKit
import Observation

// dMPP-2025-11-21-NAV3 — Folder navigation + crops + bottom nav bar + dMPMS sidecar read/write

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
            // [DMPP-SI-TOOLBAR] Top toolbar: folder only
            // -----------------------------------------------------
            HStack(spacing: 12) {

                if let folderURL {
                    // [DMPP-TB-FOLDER-SELECTED]
                    Button {
                        chooseFolder()
                    } label: {
                        Label {
                            Text(folderURL.lastPathComponent)
                                .font(.title2.bold())   // was .largeTitle, slightly smaller but still “important”
                        } icon: {
                            Image(systemName: "folder")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .help("Change folder…")
                } else {
                    // [DMPP-TB-FOLDER-NONE]
                    Button {
                        chooseFolder()
                    } label: {
                        Label("Choose Folder…", systemImage: "folder.badge.plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .help("Choose a folder to begin")
                }

                Spacer()
                // [DMPP-TB-FULL-PATH] Right-justified full path (if we have a folder)
                if let folderURL {
                    Text(folderURL.path)
                        .font(.default)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.head) // keep the tail (most specific part) visible
                }
            }
            .padding()
            .background(.thinMaterial)

            Divider()

            // -----------------------------------------------------
            // [DMPP-SI-CONTENT] Main content + bottom nav
            // -----------------------------------------------------
            if let vm {
                VStack(spacing: 0) {

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
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    Divider()

                    // -----------------------------------------------------
                    // [DMPP-SI-BOTTOM-NAV] Picture + crop navigation
                    // -----------------------------------------------------
                    HStack(spacing: 8) {
                        Spacer()

                        Button("Previous Picture") {
                            goToPreviousImage()
                        }
                        .disabled(!canGoToPrevious)

                        Button("Previous Crop") {
                            vm.selectPreviousCrop()
                        }
                        .disabled(vm.metadata.virtualCrops.isEmpty)

                        Button("Next Crop") {
                            vm.selectNextCrop()
                        }
                        .disabled(vm.metadata.virtualCrops.isEmpty)

                        Button("Next Image") {
                            goToNextImage()
                        }
                        .disabled(!canGoToNext)
                    }
                   // .padding([.horizontal, .bottom])

                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(.thinMaterial)
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

/// [DMPP-SI-LEFT] Crops + image preview + crop controls (segmented tabs above preview).
struct DMPPCropEditorPane: View {

    @Bindable var vm: DMPPImageEditorViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // -------------------------------------------------
            // [DMPP-SI-CROP-TABS] Segmented control for crop selection
            // -------------------------------------------------
            if !vm.metadata.virtualCrops.isEmpty {
                Picker(
                    "Crops",
                    selection: Binding(
                        get: {
                            vm.selectedCropID
                            ?? vm.metadata.virtualCrops.first?.id
                            ?? ""
                        },
                        set: { newID in
                            vm.selectedCropID = newID
                        }
                    )
                ) {
                    ForEach(vm.metadata.virtualCrops) { crop in
                        Text(crop.label).tag(crop.id)
                    }
                }
                .pickerStyle(.segmented)
            } else {
                Text("No crops defined. Use “New Crop” to add one.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // -------------------------------------------------
            // [DMPP-SI-PREVIEW-ROW] Main preview + vertical controls
            // -------------------------------------------------
            HStack(alignment: .center, spacing: 12) {

                // [DMPP-SI-MAIN-PREVIEW] Large image + overlay
                if let nsImage = vm.nsImage, let selectedCrop = vm.selectedCrop {
                    ZStack {
                        GeometryReader { geo in
                            ZStack {
                                Image(nsImage: nsImage)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: geo.size.width, height: geo.size.height)

                                DMPPCropOverlayView(
                                    image: nsImage,
                                    rect: selectedCrop.rect
                                ) { newRect in
                                    vm.updateVirtualCropRect(
                                        cropID: selectedCrop.id,
                                        newRect: newRect
                                    )
                                }
                            }
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(.secondary.opacity(0.3))
                    )
                } else {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.secondary.opacity(0.1))
                        .overlay(
                            Text("No image or crop selected")
                                .foregroundStyle(.secondary)
                        )
                }

                // [DMPP-SI-CROP-CONTROLS] Crop column: title, +, slider, -
                if vm.selectedCrop != nil {
                    VStack(spacing: 8) {
                        Text("Crop")
                            .font(.caption)

                        // Top: Zoom in → larger crop
                        Button {
                            vm.scaleSelectedCrop(by: 1.1)
                        } label: {
                            Image(systemName: "plus")
                        }
                        .buttonStyle(.borderedProminent)
                        .help("Larger crop")

                        Spacer(minLength: 8)

                        // Tall vertical slider whose *length* matches column height
                                           GeometryReader { sliderGeo in
                                               Slider(
                                                   value: Binding(
                                                       get: { vm.selectedCropSizeSliderValue },
                                                       set: { vm.selectedCropSizeSliderValue = $0 }
                                                   ),
                                                   in: 0...1
                                               )
                                               // IMPORTANT:
                                               // - We set the width BEFORE rotation so that
                                               //   after a -90° rotation, that width becomes
                                               //   the vertical length of the slider.
                                               .frame(width: max(sliderGeo.size.height - 40, 120))
                                               .rotationEffect(.degrees(-90))
                                               // Center the rotated slider inside the column
                                               .position(
                                                   x: sliderGeo.size.width / 2,
                                                   y: sliderGeo.size.height / 2
                                               )
                                           }
                                           .frame(maxHeight: .infinity)

                        Spacer(minLength: 8)

                        // Bottom: Zoom out → smaller crop
                        Button {
                            vm.scaleSelectedCrop(by: 0.9)
                        } label: {
                            Image(systemName: "minus")
                        }
                        .buttonStyle(.borderedProminent)
                        .help("Smaller crop")
                    }
                    .frame(width: 60)
                    .frame(maxHeight: .infinity)

                }

            }

            // [DMPP-SI-ASPECT-LABEL] Aspect label only (buttons moved to control column)
            if vm.selectedCrop != nil {
                HStack(spacing: 8) {
                    Text(vm.selectedCropAspectDescription)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)

                    Spacer()
                }
            }

            // -------------------------------------------------
            // [DMPP-SI-CROP-BUTTONS] Crop control buttons
            // -------------------------------------------------
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
                TextField("Title: ", text: $vm.metadata.title)
                TextField("Description: ", text: $vm.metadata.description, axis: .vertical)
                    .lineLimit(2...6)
            }

            Section("Date Taken") {
            //    TextField("YYYY, YYYY-MM, YYYY-MM-DD, or YYYYs",
                TextField("YYYY-MM-DD, YYYY-MM, YYYY, or YYYYs",
                          text: $vm.metadata.dateTaken)
            }

            Section("Tags & People") {
                TextField(
                    "Tags: ",
                    text: Binding(
                        get: { vm.tagsText },
                        set: { vm.updateTags($0) }
                    )
                )

                TextField(
                    "People: ",
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
            // Pretty-printed, but DO NOT sort keys alphabetically.
            encoder.outputFormatting = [.prettyPrinted]

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
    // NOTE: We no longer set default crops here; the ViewModel
    // will add aspect-correct crops once it knows the image size.
    private func makeDefaultMetadata(for url: URL) -> DmpmsMetadata {
        let filename = url.lastPathComponent
        let baseTitle = url.deletingPathExtension().lastPathComponent

        return DmpmsMetadata(
            dmpmsVersion: "1.0",
            sourceFile: filename,
            title: baseTitle,
            description: "",
            dateTaken: "",
            tags: [],
            people: [],
            virtualCrops: [],   // let VM fill these in
            history: []
        )
    }







    // [DMPP-NAV-ASPECT-RECT] Build a centered RectNormalized for a given aspect ratio.
    private func centeredRectForAspect(
        _ aspectString: String,
        imageSize: CGSize
    ) -> RectNormalized {
        let parts = aspectString.split(separator: ":")
        guard parts.count == 2,
              let w = Double(parts[0]),
              let h = Double(parts[1]),
              w > 0, h > 0
        else {
            return RectNormalized(x: 0, y: 0, width: 1, height: 1)
        }

        let targetAR = w / h
        let imageAR = Double(imageSize.width / max(imageSize.height, 1))

        // ratio of target AR to image AR
        let k = targetAR / imageAR

        let widthNorm: Double
        let heightNorm: Double

        if k >= 1 {
            // Target is "wider" than image: full width, reduce height.
            widthNorm = 1.0
            heightNorm = 1.0 / k
        } else {
            // Target is "taller" than image: full height, reduce width.
            widthNorm = k
            heightNorm = 1.0
        }

        let x = (1.0 - widthNorm) / 2.0
        let y = (1.0 - heightNorm) / 2.0

        return RectNormalized(x: x, y: y, width: widthNorm, height: heightNorm)
    }


}


#Preview {
    DMPPImageEditorView()
        .frame(width: 1000, height: 650)
}
