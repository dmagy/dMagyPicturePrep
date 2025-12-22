import SwiftUI
import AppKit
import Observation

// dMPP-2025-11-21-NAV2+UI — Folder navigation + crops + dMPMS sidecar read/write

// MARK: - Editor Root View

struct DMPPImageEditorView: View {

    // MARK: State

    @State private var vm: DMPPImageEditorViewModel? = nil

    @State private var folderURL: URL? = nil
    @State private var imageURLs: [URL] = []
    @State private var currentIndex: Int = 0

    @AppStorage("pinFavoritesToTop") private var pinFavoritesToTop: Bool = true
    @AppStorage("showAllPeopleInChecklist") private var showAllPeopleInChecklist: Bool = false
    @AppStorage("includeSubfolders") private var includeSubfolders: Bool = false
    @AppStorage("advanceToNextWithoutSidecar") private var advanceToNextWithoutSidecar: Bool = false



    // cp-2025-12-18-UNK1(UNKNOWN-STATE)
    @State private var showAddUnknownSheet: Bool = false
    @State private var unknownLabelDraft: String = ""
    @State private var activeRowIndex: Int = 0

    @State private var loadedMetadataHash: Int? = nil

    private var isSaveEnabled: Bool {
        guard let vm else { return false }
        // If we somehow don't have a baseline yet, allow save.
        guard let loadedMetadataHash else { return true }
        return metadataHash(vm.metadata) != loadedMetadataHash
    }


    // MARK: View

    var body: some View {
        VStack(spacing: 0) {

            // MARK: Toolbar

            HStack(spacing: 12) {

                if let folderURL {
                    Button {
                        chooseFolder()
                    } label: {
                        Label {
                            Text(folderURL.lastPathComponent)
                                .font(.largeTitle.bold())
                        } icon: {
                            Image(systemName: "folder")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .help("Change folder…")
                    
                        Toggle("Include subfolders", isOn: $includeSubfolders)
                            .toggleStyle(.checkbox)
                            .font(.caption)
                            .help("If enabled, Prep will scan this folder and all subfolders for pictures.")
                        Toggle("Show only un-prepped pictures", isOn: $advanceToNextWithoutSidecar)
                            .toggleStyle(.checkbox)
                            .font(.caption)
                            .help("If enabled, Prep will skip photos that already have crop or picture data saved for them")
                   
                } else {
                    Button {
                        chooseFolder()
                    } label: {
                        Label {
                            Text("Choose Folder…")
                                .font(.title2.bold())
                        } icon: {
                            Image(systemName: "folder.badge.plus")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .help("Choose a folder to begin")
                }

                Spacer()

                if let folderURL {
                    Button {
                        NSWorkspace.shared.open(folderURL)
                    } label: {
                        Text(displayPathText)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.head)
                    }
                    .buttonStyle(.plain)
                    .help(folderURL.path) // full path on hover
                }
            }
            .onChange(of: includeSubfolders) { _, _ in
                guard let folderURL else { return }
                loadImages(from: folderURL)
            }

            .padding()
            .background(.thinMaterial)

            Divider()

            // MARK: Main Content

            if let vm {

                HStack(spacing: 0) {

                    // LEFT — Crops + Preview
                    DMPPCropEditorPane(vm: vm)
                        .frame(minWidth: 400)
                        .padding()
                        .background(Color(nsColor: .windowBackgroundColor))

                    Divider()

                    // RIGHT — Metadata Form
                    DMPPMetadataFormPane(
                        vm: vm,
                        pinFavoritesToTop: $pinFavoritesToTop,
                        showAllPeopleInChecklist: $showAllPeopleInChecklist,
                        activeRowIndex: $activeRowIndex,
                        showAddUnknownSheet: $showAddUnknownSheet,
                        unknownLabelDraft: $unknownLabelDraft,
                        addUnknownPersonRow: { label in
                            let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !trimmed.isEmpty else { return }

                            let nextPos = (vm.metadata.peopleV2
                                .filter { $0.rowIndex == activeRowIndex && $0.roleHint != "rowMarker" }
                                .map(\.positionIndex)
                                .max() ?? -1) + 1

                            let newRow = DmpmsPersonInPhoto(
                                identityID: nil,
                                isUnknown: true,
                                shortNameSnapshot: trimmed,
                                displayNameSnapshot: trimmed,
                                ageAtPhoto: nil,
                                rowIndex: activeRowIndex,
                                rowName: nil,
                                positionIndex: nextPos,
                                roleHint: "unknown"
                            )

                            vm.metadata.peopleV2.append(newRow)
                            vm.recomputeAgesForCurrentImage()

                            print("ADD UNKNOWN: file=\(vm.metadata.sourceFile) activeRowIndex=\(activeRowIndex) nextPos=\(nextPos) roleHint=\(String(describing: newRow.roleHint)) rowIndex=\(newRow.rowIndex) totalPeople=\(vm.metadata.peopleV2.count)")
                            print("ADD UNKNOWN ROWS PRESENT: \(vm.metadata.peopleV2.map(\.rowIndex).sorted())")


                            // Debug breadcrumb when you need it:
                            // print("ADD UNKNOWN: activeRowIndex=\(activeRowIndex), nextPos=\(nextPos), roleHint=\(String(describing: newRow.roleHint)), rowIndex=\(newRow.rowIndex)")
                        }
                    )
                    .frame(minWidth: 320, idealWidth: 360, maxWidth: 420)
                    .padding()
                }

                // MARK: Bottom Nav Bar

                HStack(spacing: 8) {

                    if vm.selectedCrop != nil {
                        Button(action: {
                            vm.deleteSelectedCrop()
                        }) {
                            Text("Delete Crop")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(Color.red)
                                )
                        }
                        .buttonStyle(.plain)
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.white)
                        )
                        .padding(.top, -16)
                        .padding(.leading, 16)
                    }

                    Spacer(minLength: 8)

                    Text("Edits are saved separately; your original photo is never changed.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity)

                    Spacer(minLength: 8)

                    Button("Save") {
                        saveCurrentMetadata()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!isSaveEnabled)
                    .keyboardShortcut("s", modifiers: [.command])
                    .keyboardShortcut(.defaultAction) // optional, see note below
                    .help(isSaveEnabled
                          ? "Save crop and data for this picture (original picture is never changed)."
                          : "No changes to save.")

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

                    Button("Next Picture") {
                        goToNextImage()
                    }
                    .disabled(!canGoToNext)
                    .help("Changes are saved automatically.")
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(.thinMaterial)

            } else {

                // MARK: Empty State

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

    @Environment(\.openSettings) private var openSettings

    /// For the crop editor we only need read access to the view model.
    var vm: DMPPImageEditorViewModel

    /// Convenience accessor: current saved custom presets.
    private var customPresets: [DMPPUserPreferences.CustomCropPreset] {
        DMPPUserPreferences.load().customCropPresets
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            HStack(alignment: .center, spacing: 12) {

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
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text("No crops defined. Use “New Crop” to add one.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Menu("New Crop") {

                    Menu("Screen") {
                        Button("Original (full image)") { vm.addPresetOriginalCrop() }
                            .disabled(vm.hasPresetOriginal)

                        Button("Landscape 16:9") { vm.addPresetLandscape16x9() }
                            .disabled(vm.hasPresetLandscape16x9)

                        Button("Portrait 9:16") { vm.addPresetPortrait9x16() }
                            .disabled(vm.hasPresetPortrait9x16)

                        Button("Landscape 4:3") { vm.addPresetLandscape4x3() }
                            .disabled(vm.hasPresetLandscape4x3)
                    }

                    Menu("Print & Frames") {
                        Button("Portrait 8×10") { vm.addPresetPortrait8x10() }
                            .disabled(vm.hasPresetPortrait8x10)

                        Button("Headshot 8×10") { vm.addPresetHeadshot8x10() }
                            .disabled(vm.hasPresetHeadshot8x10)

                        Button("Landscape 4×6") { vm.addPresetLandscape4x6() }
                            .disabled(vm.hasPresetLandscape4x6)
                    }

                    Menu("Creative & Custom") {
                        Button("Square 1:1") { vm.addPresetSquare1x1() }
                            .disabled(vm.hasPresetSquare1x1)

                        Button("Freeform") { vm.addFreeformCrop() }

                        if !customPresets.isEmpty {
                            Divider()
                            ForEach(customPresets) { preset in
                                let alreadyExists = vm.metadata.virtualCrops.contains { crop in
                                    crop.label == preset.label &&
                                    crop.aspectRatio == "\(preset.aspectWidth):\(preset.aspectHeight)"
                                }

                                Button(preset.label) {
                                    vm.addCrop(fromCustomPreset: preset)
                                }
                                .disabled(alreadyExists)
                            }
                        }
                    }

                    Divider()

                    Button("Manage Custom Presets…") {
                        openSettings()
                    }
                }
                .padding(.trailing, 73)
            }

            HStack(alignment: .center, spacing: 12) {

                if let nsImage = vm.nsImage, let selectedCrop = vm.selectedCrop {
                    ZStack {
                        GeometryReader { geo in
                            ZStack {
                                Image(nsImage: nsImage)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: geo.size.width, height: geo.size.height)

                                let isHeadshot = selectedCrop.label.contains("Headshot")
                                let isFreeform = (selectedCrop.aspectRatio == "custom"
                                                  || selectedCrop.label == "Freeform")

                                DMPPCropOverlayView(
                                    image: nsImage,
                                    rect: selectedCrop.rect,
                                    isHeadshot: isHeadshot,
                                    isFreeform: isFreeform
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

                if vm.selectedCrop != nil {
                    GeometryReader { _ in
                        VStack(spacing: 8) {
                            Text("Crop")
                                .font(.caption)

                            Button {
                                vm.scaleSelectedCrop(by: 0.9)
                            } label: {
                                Image(systemName: "plus")
                            }
                            .buttonStyle(.borderedProminent)
                            .help("Zoom in (smaller crop)")

                            Spacer(minLength: 8)

                            GeometryReader { innerGeo in
                                Slider(
                                    value: Binding(
                                        get: { vm.selectedCropSizeSliderValue },
                                        set: { vm.selectedCropSizeSliderValue = $0 }
                                    ),
                                    in: 0...1
                                )
                                .frame(width: max(innerGeo.size.height - 40, 120))
                                .rotationEffect(.degrees(-90))
                                .position(
                                    x: innerGeo.size.width / 2,
                                    y: innerGeo.size.height / 2
                                )
                            }
                            .frame(maxHeight: .infinity)

                            Spacer(minLength: 8)

                            Button {
                                vm.scaleSelectedCrop(by: 1.1)
                            } label: {
                                Image(systemName: "minus")
                            }
                            .buttonStyle(.borderedProminent)
                            .help("Zoom out (larger crop)")
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .frame(width: 60)
                }
            }
        }
    }
}

// MARK: - Right Pane (Metadata)

struct DMPPMetadataFormPane: View {
    
    // MARK: Inputs
    
    @Bindable var vm: DMPPImageEditorViewModel
    
    @Binding var pinFavoritesToTop: Bool
    @Binding var showAllPeopleInChecklist: Bool
    
    // Row context is owned by the EditorView (per-image), but edited here.
    @Binding var activeRowIndex: Int
    
    @Binding var showAddUnknownSheet: Bool
    @Binding var unknownLabelDraft: String
    
    
    
    var addUnknownPersonRow: (String) -> Void
    
    // MARK: Env
    
    @Environment(\.openSettings) private var openSettings
    @Environment(\.openWindow) private var openWindow
    
    // MARK: Local State
    
    @State private var showCaptureSnapshotSheet: Bool = false
    @State private var snapshotNoteDraft: String = ""
    
    @State private var showResetPeopleConfirm: Bool = false
    @State private var resetSnapshotNoteDraft: String = ""
    
    @State private var availableTags: [String] = DMPPUserPreferences.load().availableTags
    @State private var dateWarning: String? = nil

    @State private var pendingResetAfterSnapshot: Bool = false

    
    // MARK: View
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                
                // MARK: File
                
                GroupBox("File") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(vm.metadata.sourceFile)
                            .font(.callout.monospaced())
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                }
                
                // MARK: Description
                
                GroupBox("Title and Description") {
                    VStack(alignment: .leading, spacing: 8) {
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Title")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            TextField("", text: $vm.metadata.title)
                                .textFieldStyle(.roundedBorder)
                                .frame(maxWidth: .infinity)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 8)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Description")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            TextField("", text: $vm.metadata.description, axis: .vertical)
                                .lineLimit(2...6)
                                .textFieldStyle(.roundedBorder)
                                .frame(maxWidth: .infinity)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 8)
                    }
                }
                
                // MARK: Date / Era
                
                GroupBox("Date Taken or Era") {
                    VStack(alignment: .leading, spacing: 6) {
           
                        
                        TextField(
                            "",
                            text: Binding(
                                get: { vm.metadata.dateTaken },
                                set: { vm.updateDateTaken($0) }
                            )
                        )
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: .infinity)
                        .onChange(of: vm.metadata.dateTaken) { _, newValue in
                            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                            vm.metadata.dateRange = DmpmsDateRange.from(dateTaken: trimmed)
                            dateWarning = dateValidationMessage(for: trimmed)
                            vm.recomputeAgesForCurrentImage()
                        }
                        
                        if let dateWarning, !dateWarning.isEmpty {
                            Text(dateWarning)
                                .font(.caption2)
                                .foregroundStyle(.red)
                        } else {
                            Text("Partial dates, decades, and ranges are allowed.\nExamples: 1976-07-04, 1976-07, 1976, 1970s, 1975-1977, 1975-12 to 1976-08")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                }
                .onAppear {
                    vm.recomputeAgesForCurrentImage()
                }
                .onChange(of: vm.metadata.sourceFile) { _, _ in
                    vm.recomputeAgesForCurrentImage()
                }
                
                // MARK: Tags
                
                GroupBox("Tags") {
                    VStack(alignment: .leading, spacing: 8) {
                 
                        
                        if availableTags.isEmpty {
                            Text("No tags defined. Use Settings to add tags.")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        } else {
                            let columns = [
                                GridItem(.flexible(), alignment: .leading),
                                GridItem(.flexible(), alignment: .leading)
                            ]
                            
                            LazyVGrid(columns: columns, alignment: .leading, spacing: 4) {
                                ForEach(availableTags, id: \.self) { tag in
                                    Toggle(
                                        isOn: Binding(
                                            get: { vm.metadata.tags.contains(tag) },
                                            set: { isOn in
                                                if isOn {
                                                    if !vm.metadata.tags.contains(tag) { vm.metadata.tags.append(tag) }
                                                } else {
                                                    vm.metadata.tags.removeAll { $0 == tag }
                                                }
                                            }
                                        )
                                    ) {
                                        Text(tag)
                                    }
                                    .toggleStyle(.checkbox)
                                }
                            }
                        }
                        
                        Button("Add / Edit tags…") { openSettings() }
                            .buttonStyle(.link)
                            .font(.caption)
                            .tint(.accentColor)
                            .padding(.top, 4)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                }
                
                // MARK: People
                
                GroupBox("People") {
                    VStack(alignment: .leading, spacing: 8) {
                        
                        // Summary (always visible)
                        VStack(alignment: .leading, spacing: 6) {
                            
                            Text("Check people in this photo left to right, row by row")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            let sortedPeople = vm.metadata.peopleV2.sorted { lhs, rhs in
                                if lhs.rowIndex == rhs.rowIndex {
                                    return lhs.positionIndex < rhs.positionIndex
                                } else {
                                    return lhs.rowIndex < rhs.rowIndex
                                }
                            }
                            
                            if sortedPeople.isEmpty {
                                Text("None yet.")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            } else {
                                // Show people on separate lines by rowIndex (reverse order)
                                let nonMarkers = sortedPeople.filter { $0.roleHint != "rowMarker" }
                                let peopleByRow = Dictionary(grouping: nonMarkers, by: { $0.rowIndex })
                                let rowIndexes = peopleByRow.keys.sorted(by: >)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    ForEach(rowIndexes, id: \.self) { (r: Int) in
                                        let rowPeople = (peopleByRow[r] ?? []).sorted { $0.positionIndex < $1.positionIndex }
                                        
                                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                                            Text("\(rowLabel(for: r)):")
                                                .font(.callout.weight(.semibold))
                                                .foregroundStyle(.secondary)
                                                .frame(width: 42, alignment: .leading) // tweak width to taste
                                            //    .frame(width: 43, alignment: .trailing) // tweak width to taste
                                            
                                            Text(peopleLineAttributed(rowPeople: rowPeople))
                                                .font(.callout) // bigger than caption
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                    }
                                    
                                    
                                }
                            }
                            
                            // -------------------------------------------------
                            // Primary actions (always visible)
                            // -------------------------------------------------
                            HStack(spacing: 10) {
                                
                                Button("Add one-off person…") {
                                    unknownLabelDraft = "One-off person"
                                    showAddUnknownSheet = true
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.regular)
                                
                                Button("Start next row") {
                                    let before = activeRowIndex
                                    let maxRow = (vm.metadata.peopleV2.map(\.rowIndex).max() ?? 0)
                                    let base = max(before, maxRow)
                                    activeRowIndex = base + 1
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.regular)
                                
                                Spacer()
                            }
                            .padding(.top, 6)
                            
                            Divider()
                                .padding(.vertical, 6)
                            
                            // -------------------------------------------------
                            // Advanced (collapsed by default): snapshots + reset
                            // -------------------------------------------------
                            DisclosureGroup("Advanced") {
                                
                                VStack(alignment: .leading, spacing: 10) {
                                    
                                    // Reset (moved to Advanced)
                                    HStack {
                                        Button(role: .destructive) {
                                            resetSnapshotNoteDraft = "Before reset \(shortNowStamp())"
                                            showResetPeopleConfirm = true
                                        } label: {
                                            Text("Reset people…")
                                        }
                                        .buttonStyle(.bordered)
                                        
                                        Spacer()
                                    }
                                    .alert("Reset people?", isPresented: $showResetPeopleConfirm) {

                                        Button("Save") {
                                            pendingResetAfterSnapshot = true
                                            snapshotNoteDraft = "Before reset \(shortNowStamp())"
                                            showCaptureSnapshotSheet = true
                                        }

                                        Button("Skip", role: .destructive) {
                                            performResetPeople(identityStore: .shared, captureSnapshot: false)
                                            activeRowIndex = 0
                                        }

                                    } message: {
                                        Text("This will clear the current People list for this photo (including one-offs and row markers). Do you want to save a snapshot for later?")
                                    }


                                    Divider()
                                        .padding(.vertical, 4)
                                    
                                    // Snapshots
                                    HStack(spacing: 10) {
                                        Text("Snapshots (\(vm.metadata.peopleV2Snapshots.count))")
                                            .font(.caption.bold())
                                            .foregroundStyle(.secondary)
                                        
                                        Spacer()
                                        
                                        Button("Capture snapshot…") {
                                            pendingResetAfterSnapshot = false
                                            snapshotNoteDraft = ""
                                            showCaptureSnapshotSheet = true
                                        }

                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                    }
                                    
                                    if vm.metadata.peopleV2Snapshots.isEmpty {
                                        Text("No snapshots yet. Capture one before making big changes.")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    } else {
                                        
                                        // newest first (inline; avoids local `let snapshots = ...`)
                                        let ordered = vm.metadata.peopleV2Snapshots.sorted { $0.createdAtISO8601 > $1.createdAtISO8601 }
                                        
                                        VStack(alignment: .leading, spacing: 8) {
                                            ForEach(ordered) { snap in

                                                VStack(alignment: .leading, spacing: 8) {

                                                    // Title row: Timestamp + actions
                                                    HStack(alignment: .firstTextBaseline, spacing: 10) {

                                                        Text(snap.createdAtISO8601)
                                                            .font(.callout.weight(.semibold))
                                                            .foregroundStyle(.secondary)

                                                        Spacer()

                                                        Button("Restore") {
                                                            restoreSnapshot(id: snap.id, identityStore: DMPPIdentityStore.shared)
                                                            activeRowIndex = (vm.metadata.peopleV2.map(\.rowIndex).max() ?? 0)
                                                        }
                                                        .buttonStyle(.borderedProminent)
                                                        .controlSize(.small)

                                                        Button(role: .destructive) {
                                                            deleteSnapshot(id: snap.id)
                                                        } label: {
                                                            Text("Delete")
                                                        }
                                                        .buttonStyle(.bordered)
                                                        .controlSize(.small)
                                                    }

                                                    // People list (FULL, multi-line)
                                                    let nonMarkers = snap.peopleV2.filter { $0.roleHint != "rowMarker" }
                                                    let grouped = Dictionary(grouping: nonMarkers, by: { $0.rowIndex })
                                                    let rowIndexes = grouped.keys.sorted(by: >)

                                                    if rowIndexes.isEmpty {
                                                        Text("No people recorded in this snapshot.")
                                                            .font(.caption2)
                                                            .foregroundStyle(.secondary)
                                                    } else {
                                                        VStack(alignment: .leading, spacing: 2) {
                                                            ForEach(rowIndexes, id: \.self) { r in
                                                                let rowPeople = (grouped[r] ?? []).sorted { $0.positionIndex < $1.positionIndex }

                                                                // Build the same “name (age)” string you use elsewhere
                                                                let line = rowPeople
                                                                    .map { person -> String in
                                                                        if let identityID = person.identityID {
                                                                            let live = vm.ageTextByIdentityID[identityID] ?? ""
                                                                            if !live.isEmpty { return "\(person.shortNameSnapshot) (\(live))" }
                                                                        }
                                                                        if let snapAge = person.ageAtPhoto, !snapAge.isEmpty {
                                                                            return "\(person.shortNameSnapshot) (\(snapAge))"
                                                                        }
                                                                        return person.shortNameSnapshot
                                                                    }
                                                                    .joined(separator: ", ")

                                                                Text("\(rowLabel(for: r)): \(line)")
                                                                    .font(.caption2)
                                                                    .foregroundStyle(.secondary)
                                                                    .fixedSize(horizontal: false, vertical: true) // allow wrapping
                                                            }
                                                        }
                                                    }

                                                    // Note (editable, BELOW the people list)
                                                    TextField(
                                                        "",
                                                        text: Binding(
                                                            get: { snap.note },
                                                            set: { newValue in
                                                                updateSnapshotNote(id: snap.id, note: newValue)
                                                            }
                                                        )
                                                    )
                                                    .textFieldStyle(.roundedBorder)

                                                }
                                            }

                                        }
                                    }
                                }
                                .padding(.top, 2)
                            }
                            .font(.caption)
                            
                            // Impossible-age warning (kept, but no standalone `let`)
                            if vm.metadata.peopleV2.contains(where: { $0.ageAtPhoto == "*" }) {
                                Text("* indicates this person appears in a photo dated before their recorded birth year. Double-check the date or the person.")
                                    .font(.caption2)
                                    .foregroundStyle(.red)
                                    .padding(.top, 2)
                            }
                            
                            
                            
                            
                            Divider()
                                .padding(.vertical, 4)
                            
                            // Checklist
                            let availablePeople: [DMPPIdentityStore.PersonSummary] =
                            showAllPeopleInChecklist
                            ? identityStore.peopleSortedForUI
                            : identityStore.peopleAliveDuring(photoRange: vm.metadata.dateRange)
                            
                            let favoriteAvailable = availablePeople.filter { $0.isFavorite }
                            let othersAvailable   = availablePeople.filter { !$0.isFavorite }
                            
                            let availableAll = (favoriteAvailable + othersAvailable)
                                .sorted { a, b in
                                    a.shortName.localizedCaseInsensitiveCompare(b.shortName) == .orderedAscending
                                }
                            
                            if availableAll.isEmpty {
                                Text("No identities defined yet. Open People Manager to add some.")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            } else {
                                
                                let ordered: [DMPPIdentityStore.PersonSummary] = {
                                    guard pinFavoritesToTop else { return availableAll }
                                    let favs = availableAll.filter { $0.isFavorite }
                                    let non  = availableAll.filter { !$0.isFavorite }
                                    return favs + non
                                }()
                                
                                let half = (ordered.count + 1) / 2
                                let leftColumn  = Array(ordered.prefix(half))
                                let rightColumn = Array(ordered.dropFirst(half))
                                
                                HStack(alignment: .top, spacing: 24) {
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        ForEach(leftColumn) { person in
                                            Toggle(identityStore.checklistLabel(for: person), isOn: bindingForPerson(person))
                                                .toggleStyle(.checkbox)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        ForEach(rightColumn) { person in
                                            Toggle(identityStore.checklistLabel(for: person), isOn: bindingForPerson(person))
                                                .toggleStyle(.checkbox)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                
                                HStack {
                                    Toggle("Show all people", isOn: $showAllPeopleInChecklist)
                                        .toggleStyle(.switch)
                                        .font(.caption)
                                    
                                    Toggle("Pin favorites to top", isOn: $pinFavoritesToTop)
                                        .toggleStyle(.switch)
                                        .font(.caption)
                                }
                                .padding(.top, 6)
                            }
                            
                            HStack(spacing: 8) {
                                Button("Open People Manager…") { openWindow(id: "People-Manager") }
                                    .buttonStyle(.link)
                                    .font(.caption)
                                    .tint(.accentColor)
                                
                                Spacer()
                            }
                            .padding(.top, 4)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 8)
                    }
                    .sheet(isPresented: $showAddUnknownSheet) {
                        VStack(alignment: .leading, spacing: 12) {
                            
                            Text("Add one-off person")
                                .font(.headline)
                            
                            Text("Adds a label for this photo only (not added to People Manager).")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            TextField("", text: $unknownLabelDraft)
                                .textFieldStyle(.roundedBorder)
                            
                            Text("Examples: “Billy Joel”, “Wedding guest”, “Unknown man in red jacket”.")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            
                            HStack {
                                Spacer()
                                
                                Button("Cancel") {
                                    showAddUnknownSheet = false
                                }
                                
                                Button("Add") {
                                    let trimmed = unknownLabelDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                                    guard !trimmed.isEmpty else { return }
                                    
                                    addUnknownPersonRow(trimmed)
                                    showAddUnknownSheet = false
                                }
                                .keyboardShortcut(.defaultAction)
                                .disabled(unknownLabelDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }
                        }
                        .padding()
                        .frame(minWidth: 420)
                    }
                    
                    .sheet(isPresented: $showCaptureSnapshotSheet) {
                        VStack(alignment: .leading, spacing: 12) {

                            Text(pendingResetAfterSnapshot ? "Save snapshot before reset" : "Capture snapshot")
                                .font(.headline)

                            Text(
                                pendingResetAfterSnapshot
                                ? "Optional note. After saving, your People list will be cleared."
                                : "This saves the current People list into the dmpms.json so you can restore it later."
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)

                            TextField("", text: $snapshotNoteDraft)
                                .textFieldStyle(.roundedBorder)
                      

                            HStack {
                                Spacer()

                                Button("Cancel") {
                                    showCaptureSnapshotSheet = false
                                    pendingResetAfterSnapshot = false
                                }

                                Button("Save") {
                                    capturePeopleSnapshot(note: snapshotNoteDraft)
                                    showCaptureSnapshotSheet = false

                                    if pendingResetAfterSnapshot {
                                        pendingResetAfterSnapshot = false
                                        performResetPeople(identityStore: .shared, captureSnapshot: false)
                                        activeRowIndex = 0
                                    }
                                }
                                .keyboardShortcut(.defaultAction)
                            }
                        }
                        .padding()
                        .frame(minWidth: 520)
                    }

                    Spacer(minLength: 0)
                }
                
                
                .padding()
                .onAppear {
                    reloadAvailableTags()
                    // Per-photo row context: default to the last row used in this photo
                    activeRowIndex = vm.metadata.peopleV2.map(\.rowIndex).max() ?? 0
                }
                .onReceive(NotificationCenter.default.publisher(for: .dmppPreferencesChanged)) { _ in
                    reloadAvailableTags()
                }
                .onChange(of: showAddUnknownSheet) { _, isShown in
                    guard isShown else { return }
                    if unknownLabelDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        unknownLabelDraft = "Unknown"
                    }
                }
                
            } // end ScrollView
        } // end body
    }
                // MARK: - Helpers (UI/People Pane)

                private func reloadAvailableTags() {
                    availableTags = DMPPUserPreferences.load().availableTags
                }

                private func shortNowStamp() -> String {
                    let f = DateFormatter()
                    f.locale = Locale(identifier: "en_US_POSIX")
                    f.dateFormat = "yyyy-MM-dd HH:mm"
                    return f.string(from: Date())
                }
    
    private func performResetPeople(identityStore: DMPPIdentityStore, captureSnapshot: Bool) {

        if captureSnapshot {
            let note = "Before reset \(shortNowStamp())"
            capturePeopleSnapshot(note: note)
        }

        vm.metadata.peopleV2.removeAll()
        vm.reconcilePeopleV2Identities(identityStore: identityStore)
        vm.recomputeAgesForCurrentImage()
    }



    
                private func capturePeopleSnapshot(note: String) {
                    let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
                    let stamp = ISO8601DateFormatter().string(from: Date())

                    let snapshot = DmpmsPeopleSnapshot(
                        id: UUID().uuidString,
                        createdAtISO8601: stamp,
                        note: trimmed, // allow blank
                        peopleV2: vm.metadata.peopleV2
                    )

                    vm.metadata.peopleV2Snapshots.append(snapshot)
                }

                private func peopleLineAttributed(rowPeople: [DmpmsPersonInPhoto]) -> AttributedString {
                    var line = AttributedString("")

                    for (idx, person) in rowPeople.enumerated() {

                        // Name (emphasize “managed” identities)
                        var namePart = AttributedString(person.shortNameSnapshot)

                        if !person.isUnknown && person.identityID != nil {
                            namePart.inlinePresentationIntent = .stronglyEmphasized
                            namePart.foregroundColor = .primary
                        } else {
                            // One-off person: readable, visually distinct
                            namePart.foregroundColor = .secondary
                        }

                        line.append(namePart)

                        // Age suffix — keep attached using NBSP so it won’t wrap mid-token
                        let suffix: String = {
                            if let identityID = person.identityID {
                                let live = vm.ageTextByIdentityID[identityID] ?? ""
                                if !live.isEmpty { return "\u{00A0}(\(live))" }
                            }
                            if let snap = person.ageAtPhoto, !snap.isEmpty {
                                return "\u{00A0}(\(snap))"
                            }
                            return ""
                        }()

                        if !suffix.isEmpty {
                            line.append(AttributedString(suffix))
                        }

                        if idx < rowPeople.count - 1 {
                            line.append(AttributedString(", "))
                        }
                    }

                    return line
                }



                private func restoreSnapshot(id: String, identityStore: DMPPIdentityStore) {
                    guard let snap = vm.metadata.peopleV2Snapshots.first(where: { $0.id == id }) else { return }
                    vm.metadata.peopleV2 = snap.peopleV2
                    vm.reconcilePeopleV2Identities(identityStore: identityStore)
                    vm.recomputeAgesForCurrentImage()
                }

                private func deleteSnapshot(id: String) {
                    vm.metadata.peopleV2Snapshots.removeAll { $0.id == id }
                }

                private func updateSnapshotNote(id: String, note: String) {
                    let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard let idx = vm.metadata.peopleV2Snapshots.firstIndex(where: { $0.id == id }) else { return }
                    vm.metadata.peopleV2Snapshots[idx].note = trimmed
                }

                private func rowLabel(for rowIndex: Int) -> String {
                    switch rowIndex {
                    case 0: return "Front"
                    default: return "Row \(rowIndex + 1)"
                    }
                }

                private func nextPositionIndex(inRow rowIndex: Int) -> Int {
                    let inRow = vm.metadata.peopleV2.filter { $0.rowIndex == rowIndex && $0.roleHint != "rowMarker" }
                    return (inRow.map(\.positionIndex).max() ?? -1) + 1
                }

                // MARK: - Identity helpers (People checklist)

                private var identityStore: DMPPIdentityStore { .shared }

                private func bindingForPerson(_ person: DMPPIdentityStore.PersonSummary) -> Binding<Bool> {
                    Binding<Bool>(
                        get: {
                            vm.metadata.peopleV2.contains(where: { row in
                                guard let iid = row.identityID,
                                      let ident = identityStore.identity(forIdentityID: iid) else {
                                    return row.shortNameSnapshot == person.shortName
                                }

                                let pid = (ident.personID?.trimmingCharacters(in: .whitespacesAndNewlines))
                                    .flatMap { $0.isEmpty ? nil : $0 }

                                let groupID = pid ?? ident.id
                                return groupID == person.id
                            })
                        },
                        set: { newValue in
                            if newValue {
                                let alreadySelected = vm.metadata.peopleV2.contains(where: { row in
                                    guard let iid = row.identityID,
                                          let ident = identityStore.identity(forIdentityID: iid) else { return false }
                                    let pid = (ident.personID?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 }
                                    let groupID = pid ?? ident.id
                                    return groupID == person.id
                                })

                                if !alreadySelected {
                                    let versions = identityStore.identityVersions(forPersonID: person.id)
                                    let photoEarliest = vm.metadata.dateRange?.earliest
                                    let chosen = identityStore.bestIdentityForPhoto(
                                        versions: versions,
                                        photoEarliestYMD: photoEarliest
                                    )

                                    let nextPos = nextPositionIndex(inRow: activeRowIndex)

                                    let newRow = DmpmsPersonInPhoto(
                                        identityID: chosen.id,
                                        isUnknown: false,
                                        shortNameSnapshot: chosen.shortName,
                                        displayNameSnapshot: chosen.fullName,
                                        ageAtPhoto: nil,
                                        rowIndex: activeRowIndex,
                                        rowName: nil,
                                        positionIndex: nextPos,
                                        roleHint: nil
                                    )

                                    vm.metadata.peopleV2.append(newRow)
                                }
                            } else {
                                vm.metadata.peopleV2.removeAll { row in
                                    guard let iid = row.identityID,
                                          let ident = identityStore.identity(forIdentityID: iid) else { return false }
                                    let pid = (ident.personID?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 }
                                    let groupID = pid ?? ident.id
                                    return groupID == person.id
                                }
                            }

                            vm.reconcilePeopleV2Identities(identityStore: identityStore)
                            vm.recomputeAgesForCurrentImage()
                        }
                    )
                }

    }


// MARK: - Navigation + Sidecar Helpers

extension DMPPImageEditorView {

    // MARK: Navigation flags

    private var canGoToPrevious: Bool {
        imageURLs.indices.contains(currentIndex - 1)
    }

    private var canGoToNext: Bool {
        if advanceToNextWithoutSidecar {
            return nextIndexWithoutSidecar(from: currentIndex + 1) != nil
        } else {
            return imageURLs.indices.contains(currentIndex + 1)
        }
    }


    // MARK: Folder picking

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

    private func hasSidecar(_ imageURL: URL) -> Bool {
        FileManager.default.fileExists(atPath: sidecarURL(for: imageURL).path)
    }

    private func nextIndexWithoutSidecar(from start: Int) -> Int? {
        guard start < imageURLs.count else { return nil }
        for i in start..<imageURLs.count {
            if !hasSidecar(imageURLs[i]) { return i }
        }
        return nil
    }

    
    private func loadImages(from folder: URL) {
        // Save current image metadata before switching folders / re-scanning
        saveCurrentMetadata()

        folderURL = folder

        let found: [URL] = includeSubfolders
            ? recursiveImageURLs(in: folder)
            : immediateImageURLs(in: folder)

        // Sort by relative path so subfolders feel stable/expected
        let basePath = folder.path
        imageURLs = found.sorted {
            $0.path.replacingOccurrences(of: basePath + "/", with: "")
                < $1.path.replacingOccurrences(of: basePath + "/", with: "")
        }

        if imageURLs.isEmpty {
            vm = nil
            loadedMetadataHash = nil
            currentIndex = 0
            activeRowIndex = 0
        } else {
            loadImage(at: 0)
        }
    }

    private func immediateImageURLs(in folder: URL) -> [URL] {
        let fm = FileManager.default
        let keys: [URLResourceKey] = [.isRegularFileKey]

        let urls = (try? fm.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
        )) ?? []

        return urls.filter { dmppIsSupportedImageURL($0) }

    }

    private var displayPathText: String {
        guard let folderURL else { return "" }

        // If includeSubfolders is on, show root + relative folder of current image (if any).
        if includeSubfolders,
           imageURLs.indices.contains(currentIndex) {

            let imageURL = imageURLs[currentIndex]
            let parent = imageURL.deletingLastPathComponent()

            // If the image is inside the selected folder (or a subfolder), show relative path.
            if parent.path.hasPrefix(folderURL.path) {
                let rel = parent.path
                    .replacingOccurrences(of: folderURL.path, with: "")
                    .trimmingCharacters(in: CharacterSet(charactersIn: "/"))

                if rel.isEmpty {
                    return folderURL.lastPathComponent
                } else {
                    // Use a friendly separator
                    return "\(folderURL.lastPathComponent) ▸ \(rel.replacingOccurrences(of: "/", with: " ▸ "))"
                }
            }
        }

        // Default: last 3 path components
        let parts = folderURL.pathComponents
        let tail = parts.suffix(3).joined(separator: " / ")
        return tail
    }

    
    private func recursiveImageURLs(in folder: URL) -> [URL] {
        let fm = FileManager.default
        let keys: [URLResourceKey] = [.isRegularFileKey]

        guard let enumerator = fm.enumerator(
            at: folder,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return [] }

        var results: [URL] = []
        for case let url as URL in enumerator {
            // avoid counting directories (enumerator returns both)
            let isFile = (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) ?? false
            guard isFile else { continue }
            guard dmppIsSupportedImageURL(url) else { continue }
            results.append(url)
        }
        return results
    }


    // MARK: Row sync (per-image)

    // cp-2025-12-21-ROW-SYNC
    private func syncActiveRowIndexFromCurrentPhoto() {
        guard let editorVM = self.vm else {
            activeRowIndex = 0
            print("ROW SYNC: vm=nil -> activeRowIndex=0")
            return
        }

        let maxRow = editorVM.metadata.peopleV2.map(\.rowIndex).max() ?? 0
        print("ROW SYNC: file=\(editorVM.metadata.sourceFile) peopleV2.count=\(editorVM.metadata.peopleV2.count) maxRow=\(maxRow) -> activeRowIndex=\(maxRow)")

        activeRowIndex = maxRow
    }


    // MARK: Image navigation

    private func loadImage(at index: Int) {
        guard imageURLs.indices.contains(index) else { return }

        saveCurrentMetadata()

        currentIndex = index
        let url = imageURLs[index]

        let metadata = loadMetadata(for: url)
        let newVM = DMPPImageEditorViewModel(imageURL: url, metadata: metadata)

        newVM.wireAgeRefresh()
        newVM.stripMissingPeopleV2Identities(identityStore: .shared)
        newVM.reconcilePeopleV2Identities(identityStore: .shared)
        newVM.recomputeAgesForCurrentImage()

        vm = newVM

        // Baseline for dirty tracking (after reconciliation)
        loadedMetadataHash = metadataHash(newVM.metadata)

        // Critical: row context is per-image
        syncActiveRowIndexFromCurrentPhoto()
    }



    private func goToPreviousImage() {
        let newIndex = currentIndex - 1
        guard imageURLs.indices.contains(newIndex) else { return }
        loadImage(at: newIndex)
    }

    private func goToNextImage() {
        let start = currentIndex + 1
        guard imageURLs.indices.contains(start) else { return }

        if advanceToNextWithoutSidecar {
            guard let idx = nextIndexWithoutSidecar(from: start) else { return }
            loadImage(at: idx)
        } else {
            loadImage(at: start)
        }
    }


    // MARK: Sidecar Read/Write

    private func sidecarURL(for imageURL: URL) -> URL {
        imageURL.appendingPathExtension("dmpms.json")
    }

    private func saveCurrentMetadata() {
        guard let vm else {
            print("dMPP: saveCurrentMetadata() — no VM, nothing to save")
            return
        }

        var metadataToSave = vm.metadata

        // --- peopleV2 cleanup before save ---
        let store = DMPPIdentityStore.shared
        let photoEarliest = metadataToSave.dateRange?.earliest

        metadataToSave.peopleV2.removeAll { row in
            guard let id = row.identityID else { return false }
            return store.identity(withID: id) == nil
        }

        for i in metadataToSave.peopleV2.indices {
            guard
                let currentID = metadataToSave.peopleV2[i].identityID,
                let currentIdentity = store.identity(withID: currentID)
            else { continue }

            let pid = currentIdentity.personID ?? currentIdentity.id
            let versions = store.identityVersions(forPersonID: pid)
            guard !versions.isEmpty else { continue }

            let chosen = store.bestIdentityForPhoto(
                versions: versions,
                photoEarliestYMD: photoEarliest
            )

            metadataToSave.peopleV2[i].identityID = chosen.id
            metadataToSave.peopleV2[i].shortNameSnapshot = chosen.shortName
            metadataToSave.peopleV2[i].displayNameSnapshot = chosen.fullName

            metadataToSave.peopleV2[i].ageAtPhoto = ageDescription(
                birthDateString: chosen.birthDate,
                range: metadataToSave.dateRange
            )
        }

        metadataToSave.syncLegacyPeopleFromPeopleV2IfNeeded()
        vm.metadata = metadataToSave

        let url = sidecarURL(for: vm.imageURL)

        // Precompute what "saved" would mean
        let newBaseline = metadataHash(metadataToSave)

        print("dMPP: Attempting to save metadata for \(metadataToSave.sourceFile) to:")
        print("      \(url.path)")

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted]

            let data = try encoder.encode(metadataToSave)
            try data.write(to: url, options: .atomic)

            // Only now: mark clean
            loadedMetadataHash = newBaseline

            print("dMPP: ✅ Saved metadata successfully.")
        } catch {
            let nsError = error as NSError
            print("dMPP: ❌ Failed to save metadata for \(metadataToSave.sourceFile)")
            print("      Domain: \(nsError.domain)")
            print("      Code:   \(nsError.code)")
            print("      Desc:   \(nsError.localizedDescription)")
        }
    }



    private func metadataHash(_ m: DmpmsMetadata) -> Int {
        var h = Hasher()

        h.combine(m.title)
        h.combine(m.description)
        h.combine(m.dateTaken)

        // Tags: stable order
        for t in m.tags.sorted() { h.combine(t) }

        // People: stable order, exclude derived ageAtPhoto (prevents churn)
        let peopleSorted = m.peopleV2.sorted {
            if $0.rowIndex != $1.rowIndex { return $0.rowIndex < $1.rowIndex }
            if $0.positionIndex != $1.positionIndex { return $0.positionIndex < $1.positionIndex }
            return $0.shortNameSnapshot < $1.shortNameSnapshot
        }

        for p in peopleSorted {
            h.combine(p.identityID)
            h.combine(p.isUnknown)
            h.combine(p.shortNameSnapshot)
            h.combine(p.displayNameSnapshot)
            h.combine(p.rowIndex)
            h.combine(p.positionIndex)
            h.combine(p.roleHint)
            // DO NOT include p.ageAtPhoto here
        }

        // Crops: stable order
        let cropsSorted = m.virtualCrops.sorted { $0.id < $1.id }
        for c in cropsSorted {
            h.combine(c.id)
            h.combine(c.label)
            h.combine(c.aspectRatio)
            h.combine(c.rect.x)
            h.combine(c.rect.y)
            h.combine(c.rect.width)
            h.combine(c.rect.height)
        }

        return h.finalize()
    }

    
    private func reconcilePeopleV2AndLegacy(in metadata: inout DmpmsMetadata) -> Bool {
        let store = DMPPIdentityStore.shared
        let photoEarliest = metadata.dateRange?.earliest

        var changed = false

        let beforeCount = metadata.peopleV2.count
        metadata.peopleV2.removeAll { row in
            guard let id = row.identityID else { return false }
            return store.identity(withID: id) == nil
        }
        if metadata.peopleV2.count != beforeCount { changed = true }

        for i in metadata.peopleV2.indices {
            guard
                let currentID = metadata.peopleV2[i].identityID,
                let currentIdentity = store.identity(withID: currentID)
            else { continue }

            let pid = currentIdentity.personID ?? currentIdentity.id
            let versions = store.identityVersions(forPersonID: pid)
            guard !versions.isEmpty else { continue }

            let chosen = store.bestIdentityForPhoto(versions: versions, photoEarliestYMD: photoEarliest)

            if metadata.peopleV2[i].identityID != chosen.id { changed = true }
            metadata.peopleV2[i].identityID = chosen.id
            metadata.peopleV2[i].shortNameSnapshot = chosen.shortName
            metadata.peopleV2[i].displayNameSnapshot = chosen.fullName
            metadata.peopleV2[i].ageAtPhoto = ageDescription(
                birthDateString: chosen.birthDate,
                range: metadata.dateRange
            )
        }

        let beforePeople = metadata.people
        metadata.syncLegacyPeopleFromPeopleV2IfNeeded()
        if metadata.people != beforePeople { changed = true }

        return changed
    }

    private func loadMetadata(for imageURL: URL) -> DmpmsMetadata {
        let sidecar = sidecarURL(for: imageURL)
        let fm = FileManager.default

        if fm.fileExists(atPath: sidecar.path) {
            do {
                let data = try Data(contentsOf: sidecar)
                var metadata = try JSONDecoder().decode(DmpmsMetadata.self, from: data)

                metadata.sourceFile = imageURL.lastPathComponent
                _ = reconcilePeopleV2AndLegacy(in: &metadata)

                return metadata
            } catch {
                print("dMPP: Failed to read metadata from \(sidecar.lastPathComponent): \(error)")
                return makeDefaultMetadata(for: imageURL)
            }
        } else {
            return makeDefaultMetadata(for: imageURL)
        }
    }

    private func makeDefaultMetadata(for url: URL) -> DmpmsMetadata {
        let filename = url.lastPathComponent
        let baseTitle = url.deletingPathExtension().lastPathComponent

        return DmpmsMetadata(
            dmpmsVersion: "1.1",
            dmpmsNotice: "Created by dMagy Picture Prep. Stores metadata and crop settings for this photo. Deleting it erases edits (not the original image).",
            sourceFile: filename,
            title: baseTitle,
            description: "",
            dateTaken: "",
            tags: [],
            people: [],
            virtualCrops: [],
            history: []
        )
    }

    // MARK: Age formatting used for saved snapshots

    private func ageDescription(birthDateString: String?, range: DmpmsDateRange?) -> String? {
        guard
            let birth = birthDateString?.trimmingCharacters(in: .whitespacesAndNewlines),
            !birth.isEmpty,
            let range
        else { return nil }

        guard let birthYear = Int(birth.prefix(4)) else { return nil }

        func year(from ymd: String) -> Int? {
            let t = ymd.trimmingCharacters(in: .whitespacesAndNewlines)
            guard t.count >= 4 else { return nil }
            return Int(t.prefix(4))
        }

        guard let y1 = year(from: range.earliest),
              let y2 = year(from: range.latest) else { return nil }

        let minAge = max(0, y1 - birthYear)
        let maxAge = max(0, y2 - birthYear)

        if minAge == maxAge { return "\(minAge)" }

        if (maxAge - minAge) <= 2 {
            return "\(minAge)–\(maxAge)"
        }

        let mid = (minAge + maxAge) / 2
        let decade = (mid / 10) * 10
        let within = mid - decade

        let band: String
        switch within {
        case 0...3: band = "early"
        case 4...6: band = "mid"
        default:    band = "late"
        }

        return "\(band) \(decade)s"
    }

    
    
    // MARK: Crop math helper

    private func centeredRectForAspect(_ aspectString: String, imageSize: CGSize) -> RectNormalized {
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

        let k = targetAR / imageAR

        let widthNorm: Double
        let heightNorm: Double

        if k >= 1 {
            widthNorm = 1.0
            heightNorm = 1.0 / k
        } else {
            widthNorm = k
            heightNorm = 1.0
        }

        let x = (1.0 - widthNorm) / 2.0
        let y = (1.0 - heightNorm) / 2.0

        return RectNormalized(x: x, y: y, width: widthNorm, height: heightNorm)
    }
}

// MARK: - Date validation helper (file-scope)

private func dateValidationMessage(for raw: String) -> String? {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }

    let fullDate     = #"^\d{4}-\d{2}-\d{2}$"#
    let yearMonth    = #"^\d{4}-\d{2}$"#
    let yearOnly     = #"^\d{4}$"#
    let decade       = #"^\d{4}s$"#
    let yearRange    = #"^(\d{4})-(\d{4})$"#
    let monthRange   = #"^(\d{4})-(\d{2})-(\d{4})-(\d{2})$"#
    let monthRangeTo = #"^(\d{4})-(\d{2})\s+to\s+(\d{4})-(\d{2})$"#

    func matches(_ pattern: String) -> NSTextCheckingResult? {
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
        return regex?.firstMatch(in: trimmed, options: [], range: range)
    }

    if matches(fullDate) != nil { return nil }
    if matches(yearMonth) != nil { return nil }
    if matches(yearOnly) != nil { return nil }
    if matches(decade) != nil { return nil }

    if let match = matches(yearRange) {
        if match.numberOfRanges == 3,
           let startRange = Range(match.range(at: 1), in: trimmed),
           let endRange   = Range(match.range(at: 2), in: trimmed) {

            let startYear = Int(trimmed[startRange]) ?? 0
            let endYear   = Int(trimmed[endRange]) ?? 0

            if endYear < startYear {
                return "End year must not be earlier than start year."
            } else {
                return nil
            }
        }
    }

    if let match = matches(monthRange) {
        if match.numberOfRanges == 5,
           let sYRange = Range(match.range(at: 1), in: trimmed),
           let sMRange = Range(match.range(at: 2), in: trimmed),
           let eYRange = Range(match.range(at: 3), in: trimmed),
           let eMRange = Range(match.range(at: 4), in: trimmed) {

            let sY = Int(trimmed[sYRange]) ?? 0
            let sM = Int(trimmed[sMRange]) ?? 0
            let eY = Int(trimmed[eYRange]) ?? 0
            let eM = Int(trimmed[eMRange]) ?? 0

            if !(1...12).contains(sM) || !(1...12).contains(eM) {
                return "Months must be between 01 and 12."
            }
            if eY < sY || (eY == sY && eM < sM) {
                return "End month must not be earlier than start month."
            }
            return nil
        }
    }

    if let match = matches(monthRangeTo) {
        if match.numberOfRanges == 5,
           let sYRange = Range(match.range(at: 1), in: trimmed),
           let sMRange = Range(match.range(at: 2), in: trimmed),
           let eYRange = Range(match.range(at: 3), in: trimmed),
           let eMRange = Range(match.range(at: 4), in: trimmed) {

            let sY = Int(trimmed[sYRange]) ?? 0
            let sM = Int(trimmed[sMRange]) ?? 0
            let eY = Int(trimmed[eYRange]) ?? 0
            let eM = Int(trimmed[eMRange]) ?? 0

            if !(1...12).contains(sM) || !(1...12).contains(eM) {
                return "Months must be between 01 and 12."
            }
            if eY < sY || (eY == sY && eM < sM) {
                return "End month must not be earlier than start month."
            }
            return nil
        }
    }

    return "Entered value does not match standard forms \nExamples: 1976-07-04, 1976-07, 1976, 1970s, 1975-1977, 1975-12 to 1976-08"
}
// MARK: - File-scope helpers

fileprivate func dmppIsSupportedImageURL(_ url: URL) -> Bool {
    let ext = url.pathExtension.lowercased()
    return ["jpg", "jpeg", "png", "heic", "tif", "tiff", "webp"].contains(ext)
}

// MARK: - Preview

#Preview {
    DMPPImageEditorView()
        .frame(width: 1000, height: 650)
}
