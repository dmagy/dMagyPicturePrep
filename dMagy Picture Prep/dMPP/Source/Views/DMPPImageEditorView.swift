import SwiftUI
import AppKit
import Observation
import Foundation

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

    // Persisted folder + scoped access
    @State private var lastFolderURL: URL? = nil
    @State private var showContinueError: Bool = false
    @State private var continueErrorMessage: String = ""
    @State private var activeScopedFolderURL: URL? = nil
    @State private var activeScopedFolderOK: Bool = false

    private let kLastFolderBookmark = "dmpp.lastFolderBookmark"
    private let kLastFolderName = "dmpp.lastFolderName"
    private let kLastIncludeSubfolders = "dmpp.lastIncludeSubfolders"
    private let kLastUnpreppedOnly = "dmpp.lastUnpreppedOnly"

    private var isSaveEnabled: Bool {
        guard let vm else { return false }
        guard let loadedMetadataHash else { return true }
        return metadataHash(vm.metadata) != loadedMetadataHash
    }

    // MARK: View

    var body: some View {
        VStack(spacing: 0) {
            toolbarView
            Divider()
            mainContentView
        }
        .onAppear { loadPersistedLastFolder() }
        .onDisappear { endScopedAccess() }
        .alert("Can’t continue", isPresented: $showContinueError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(continueErrorMessage)
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var toolbarView: some View {
        HStack(spacing: 12) {

            // ---------------------------------------------------------
            // Start + Scope (left cluster)
            // ---------------------------------------------------------
            HStack(spacing: 12) {

                Button {
                    chooseFolder()
                } label: {
                    Label {
                        Text(folderURL?.lastPathComponent ?? "Choose Folder…")
                            .font(.title2.bold())
                    } icon: {
                        Image(systemName: folderURL == nil ? "folder.badge.plus" : "folder")
                    }
                }
                .buttonStyle(.borderedProminent)
                .help(folderURL == nil ? "Choose a folder to begin" : "Change folder…")

                // Show “Continue” only when no folder is currently loaded.
                if folderURL == nil, canContinueLastFolder {
                    Button {
                        continueLastFolder()
                    } label: {
                        Label(lastFolderNameForUI, systemImage: "arrow.clockwise")
                            .font(.title2.bold())
                    }
                    .buttonStyle(.borderedProminent)
                    .help("Continue where you left off.")
                }

                if folderURL != nil {
                    Toggle("Include subfolders", isOn: $includeSubfolders)
                        .toggleStyle(.checkbox)
                        .font(.callout)
                        .help("Scan this folder and all subfolders for pictures.")

                    Toggle("Show only unprepped pictures", isOn: $advanceToNextWithoutSidecar)
                        .toggleStyle(.checkbox)
                        .font(.callout)
                        .help("Skip photos that already have saved prep data.")
                }
            }

            Spacer(minLength: 16)

            // Right cluster
            if let folderURL {
                let currentURL = vm?.imageURL
                let filename = currentURL?.lastPathComponent ?? vm?.metadata.sourceFile ?? "—"
                let positionText: String = {
                    guard !imageURLs.isEmpty else { return "" }
                    return "\(currentIndex + 1) of \(imageURLs.count)"
                }()

                VStack(alignment: .trailing, spacing: 2) {
                    Button {
                        if let currentURL { revealInFinder(currentURL) }
                    } label: {
                        Text(filename)
                            .font(.title3.weight(.semibold))
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .buttonStyle(.plain)
                    .help(currentURL?.path ?? filename)

                    HStack(spacing: 10) {
                        if !positionText.isEmpty {
                            Text(positionText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Button {
                            NSWorkspace.shared.open(folderURL)
                        } label: {
                            Text(displayPathText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.head)
                        }
                        .buttonStyle(.plain)
                        .help(folderURL.path)
                    }
                }
            }
        }
        .onChange(of: includeSubfolders) { _, _ in
            guard let folderURL else { return }
            loadImages(from: folderURL)
        }
        .padding()
        .background(.thinMaterial)
    }

    @ViewBuilder
    private var mainContentView: some View {
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

                        let nextPos = nextPositionIndex(inRow: activeRowIndex)

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
                    }
                )
                .frame(minWidth: 320, idealWidth: 360, maxWidth: 420)
                .padding()
            }

            bottomBarView(vm: vm)

        } else {
            emptyStateView
        }
    }

    @ViewBuilder
    private func bottomBarView(vm: DMPPImageEditorViewModel) -> some View {
        HStack(spacing: 8) {

            if vm.selectedCrop != nil {
                Button {
                    vm.deleteSelectedCrop()
                } label: {
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

            Button("Save") { saveCurrentMetadata() }
                .buttonStyle(.borderedProminent)
                .disabled(!isSaveEnabled)
                .keyboardShortcut("s", modifiers: [.command])
                .help(isSaveEnabled
                      ? "Save crop and data for this picture (original picture is never changed)."
                      : "No changes to save.")

            Button("Previous Picture") { goToPreviousImage() }
                .disabled(!canGoToPrevious)

            Button("Previous Crop") { vm.selectPreviousCrop() }
                .disabled(vm.metadata.virtualCrops.isEmpty)

            Button("Next Crop") { vm.selectNextCrop() }
                .disabled(vm.metadata.virtualCrops.isEmpty)

            Button("Next Picture") { goToNextImage() }
                .disabled(!canGoToNext)
                .help("Changes are saved automatically.")
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.thinMaterial)
    }

    @ViewBuilder
    private var emptyStateView: some View {
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

    private var cropPickerSelection: Binding<String> {
        Binding(
            get: {
                vm.selectedCropID
                ?? vm.metadata.virtualCrops.first?.id
                ?? ""
            },
            set: { newID in
                vm.selectedCropID = newID
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            HStack(alignment: .center, spacing: 12) {

                if !vm.metadata.virtualCrops.isEmpty {
                    Picker("Crops", selection: cropPickerSelection) {
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

                    Button("Manage Custom Presets…") { openSettings() }
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

                            Button { vm.scaleSelectedCrop(by: 0.9) } label: {
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

                            Button { vm.scaleSelectedCrop(by: 1.1) } label: {
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
    @State private var availableTags: [String] = DMPPUserPreferences.load().availableTags
    @State private var dateWarning: String? = nil
    @State private var pendingResetAfterSnapshot: Bool = false

    // cp-2025-12-26-LOC-UI2(STATE)
    @State private var userLocations: [DMPPUserLocation] = []
    @State private var selectedUserLocationID: UUID? = nil

    // MARK: View

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                titleAndDescriptionSection
                dateSection
                tagsSection
                peopleSection
                locationSection

                Spacer(minLength: 0)
            }
            .onAppear {
                reloadAvailableTags()
                reloadUserLocations()
                syncSavedLocationSelectionForCurrentPhoto()
                activeRowIndex = vm.metadata.peopleV2.map(\.rowIndex).max() ?? 0
            }
            .onReceive(NotificationCenter.default.publisher(for: .dmppPreferencesChanged)) { _ in
                reloadAvailableTags()
                reloadUserLocations()
                // Don’t auto-change selection here (preferences changed ≠ photo changed)
            }
            .onChange(of: vm.metadata.sourceFile) { _, _ in
                // New photo loaded
                syncSavedLocationSelectionForCurrentPhoto()
            }
            .onChange(of: gpsKey) { _, _ in
                // GPS appeared/disappeared/changed
                syncSavedLocationSelectionForCurrentPhoto()
            }
            .onChange(of: showAddUnknownSheet) { _, isShown in
                guard isShown else { return }
                if unknownLabelDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    unknownLabelDraft = "Unknown"
                }
            }
        }
        .sheet(isPresented: $showAddUnknownSheet) { addUnknownSheet }
        .sheet(isPresented: $showCaptureSnapshotSheet) { captureSnapshotSheet }
    }

    // MARK: Sections

    private var titleAndDescriptionSection: some View {
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
    }

    private var dateSection: some View {
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
        .onAppear { vm.recomputeAgesForCurrentImage() }
        .onChange(of: vm.metadata.sourceFile) { _, _ in
            vm.recomputeAgesForCurrentImage()
        }
    }

    // cp-2025-12-26-LOC-UI2(SECTION)
    private var locationSection: some View {
        GroupBox("Location") {
            VStack(alignment: .leading, spacing: 10) {

                // GPS readout (read-only)
                if let gps = vm.metadata.gps {
                    Text("GPS: \(gps.latitude), \(gps.longitude)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    Text("GPS: (none)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                // Saved-location picker
                HStack(spacing: 10) {
                    Picker("Saved", selection: $selectedUserLocationID) {
                        Text("—").tag(UUID?.none)

                        ForEach(userLocations) { loc in
                            Text(loc.shortName.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines))
                                .tag(Optional(loc.id))
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onChange(of: selectedUserLocationID) { _, newValue in
                        // Selection = overwrite (including clearing fields when saved loc has nils)
                        guard newValue != nil else { return }
                        applySelectedUserLocationOverwriteAll()
                    }

                    Button("Reset") {
                        resetLocationToGPS()
                    }
                    .buttonStyle(.bordered)
                }

                // Show the saved description (if a saved one is selected)
                if let loc = selectedUserLocation {
                    let desc = (loc.description ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                    if !desc.isEmpty {
                        Text(desc)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Divider().padding(.vertical, 2)

                // Per-photo editable fields
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Short Name")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        TextField("Ashcroft", text: bindingLocation(\.shortName))
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Description")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        TextField("Our Family House", text: bindingLocation(\.description))
                    }
                }

                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Street Address")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        TextField("1418 Ashcroft Dr", text: bindingLocation(\.streetAddress))
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("City")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        TextField("Longmont", text: bindingLocation(\.city))
                            .frame(width: 160)
                    }
                }

                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("State")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        TextField("Colorado", text: bindingLocation(\.state))
                            .frame(width: 160)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Country")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        TextField("United States", text: bindingLocation(\.country))
                            .frame(width: 200)
                    }

                    Spacer()

                    Button("Clear") { vm.metadata.location = nil }
                        .buttonStyle(.bordered)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
        }
    }

    private var tagsSection: some View {
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
                            Toggle(tag, isOn: bindingForTag(tag))
                                .toggleStyle(.checkbox)
                        }
                    }
                }

                Button("Add / Edit tags in Settings") { openSettings() }
                    .buttonStyle(.link)
                    .font(.caption)
                    .tint(.accentColor)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
        }
    }

    private var peopleSection: some View {
        GroupBox("People") {
            VStack(alignment: .leading, spacing: 8) {

                Text("Check people in this photo left to right, row by row")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                peopleSummaryBlock

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
                        activeRowIndex = max(before, maxRow) + 1
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)

                    Spacer()
                }
                .padding(.top, 6)

                Divider().padding(.vertical, 6)

                DisclosureGroup("Advanced") {
                    advancedPeopleBlock
                        .padding(.top, 2)
                }
                .font(.caption)

                if vm.metadata.peopleV2.contains(where: { $0.ageAtPhoto == "*" }) {
                    Text("* indicates this person appears in a photo dated before their recorded birth year. Double-check the date or the person.")
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .padding(.top, 2)
                }

                Divider().padding(.vertical, 4)

                checklistBlock

                HStack(spacing: 8) {
                    Button("Add / Edit People in People Manager…") { openWindow(id: "People-Manager") }
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
    }

    // MARK: Sub-blocks

    @ViewBuilder
    private var peopleSummaryBlock: some View {
        let rows = peopleRowsForSummary()

        if rows.isEmpty {
            Text("None yet.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(rows, id: \.rowIndex) { row in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\(rowLabel(for: row.rowIndex)):")
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 42, alignment: .leading)

                        Text(peopleLineAttributed(rowPeople: row.people))
                            .font(.callout)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }

    private var advancedPeopleBlock: some View {
        VStack(alignment: .leading, spacing: 10) {

            HStack {
                Button(role: .destructive) {
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
                    performResetPeople(captureSnapshot: false)
                    activeRowIndex = 0
                }
            } message: {
                Text("This will clear the current People list for this photo (including one-offs and row markers). Do you want to save a snapshot for later?")
            }

            Divider().padding(.vertical, 4)

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
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(orderedSnapshots) { snap in
                        snapshotRow(snap)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func snapshotRow(_ snap: DmpmsPeopleSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(snap.createdAtISO8601)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                Button("Restore") {
                    restoreSnapshot(id: snap.id)
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

            let rows = peopleRowsForSnapshot(snap)
            if rows.isEmpty {
                Text("No people recorded in this snapshot.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(rows, id: \.rowIndex) { row in
                        Text("\(rowLabel(for: row.rowIndex)): \(row.line)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            TextField(
                "",
                text: Binding(
                    get: { snap.note },
                    set: { updateSnapshotNote(id: snap.id, note: $0) }
                )
            )
            .textFieldStyle(.roundedBorder)
        }
    }

    @ViewBuilder
    private var checklistBlock: some View {
        let ordered = orderedChecklistPeople()

        if ordered.isEmpty {
            Text("No identities defined yet. Open People Manager to add some.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        } else {
            let half = (ordered.count + 1) / 2
            let leftColumn = Array(ordered.prefix(half))
            let rightColumn = Array(ordered.dropFirst(half))

            HStack(alignment: .top, spacing: 24) {

                VStack(alignment: .leading, spacing: 4) {
                    ForEach(leftColumn) { person in
                        Toggle(isOn: bindingForPerson(person)) {
                            HStack(spacing: 6) {
                                Text(identityStore.checklistLabel(for: person))
                                if person.kind == "pet" {
                                    Image(systemName: "pawprint.fill")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .accessibilityLabel("Pet")
                                }
                            }
                        }
                        .toggleStyle(.checkbox)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 4) {
                    ForEach(rightColumn) { person in
                        Toggle(isOn: bindingForPerson(person)) {
                            HStack(spacing: 6) {
                                Text(identityStore.checklistLabel(for: person))
                                if person.kind == "pet" {
                                    Image(systemName: "pawprint.fill")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .accessibilityLabel("Pet")
                                }
                            }
                        }
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
    }

    // MARK: Sheets

    private var addUnknownSheet: some View {
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

                Button("Cancel") { showAddUnknownSheet = false }

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

    private var captureSnapshotSheet: some View {
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
                        performResetPeople(captureSnapshot: false)
                        activeRowIndex = 0
                    }
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(minWidth: 520)
    }
}

// MARK: - Helpers (Metadata Pane)

private extension DMPPMetadataFormPane {

    var identityStore: DMPPIdentityStore { .shared }

    // A stable Equatable key so onChange compiles even if gps type isn’t Equatable.
    var gpsKey: String {
        guard let gps = vm.metadata.gps else { return "no-gps" }
        return "\(gps.latitude)|\(gps.longitude)|\(gps.altitudeMeters ?? 0)"
    }

    // cp-2025-12-30(LOC-DROPDOWN-DEFAULT)
    func syncSavedLocationSelectionForCurrentPhoto() {
        // Requirement: if the photo has *no GPS*, dropdown should be blank.
        guard vm.metadata.gps != nil else {
            selectedUserLocationID = nil
            return
        }
        // If there *is* GPS, do not force a selection.
    }

    // cp-2025-12-26-LOC-UI2(BINDINGS)
    func bindingLocation(_ keyPath: WritableKeyPath<DmpmsLocation, String?>) -> Binding<String> {
        Binding<String>(
            get: { vm.metadata.location?[keyPath: keyPath] ?? "" },
            set: { newValue in
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)

                if vm.metadata.location == nil {
                    vm.metadata.location = DmpmsLocation()
                }

                vm.metadata.location?[keyPath: keyPath] = trimmed.isEmpty ? nil : trimmed

                // If user clears everything, drop back to nil
                if let loc = vm.metadata.location {
                    let allEmpty =
                        (loc.streetAddress?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true) &&
                        (loc.city?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true) &&
                        (loc.state?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true) &&
                        (loc.country?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)

                    if allEmpty { vm.metadata.location = nil }
                }
            }
        )
    }

    // cp-2025-12-26-LOC-UI2(MAPS+FILL)

    private func fillLocationFromGPS(overwrite: Bool) {
        guard let gps = vm.metadata.gps else { return }

        // If not overwriting, only fill when empty
        if !overwrite, vm.metadata.location != nil { return }

        Task {
            if let loc = await DMPPPhotoLocationReader.reverseGeocode(gps) {
                let prefs = DMPPUserPreferences.load()
                let match = prefs.matchingUserLocation(for: loc)

                await MainActor.run {
                    // Re-check at apply time to avoid races (user may have edited while geocoding).
                    if !overwrite, vm.metadata.location != nil { return }

                    // Apply the resolved location
                    vm.metadata.location = loc

                    // If the resolved address matches one of the user's saved locations,
                    // carry over the friendly shortName + description.
                    if let match {
                        if overwrite || (vm.metadata.location?.shortName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true) {
                            vm.metadata.location?.shortName = match.shortName
                        }
                        if overwrite || (vm.metadata.location?.description?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true) {
                            vm.metadata.location?.description = match.description
                        }
                    }
                }
            }
        }
    }

    // cp-2025-12-30(LOC-APPLY-OVERWRITE)
    func applySelectedUserLocationOverwriteAll() {
        guard let loc = selectedUserLocation else { return }

        if vm.metadata.location == nil { vm.metadata.location = DmpmsLocation() }

        func normOrNil(_ s: String?) -> String? {
            let t = (s ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return t.isEmpty ? nil : t
        }

        // Overwrite *everything*, including clearing values where saved loc has nil/empty.
        vm.metadata.location?.shortName = normOrNil(loc.shortName)
        vm.metadata.location?.description = normOrNil(loc.description)
        vm.metadata.location?.streetAddress = normOrNil(loc.streetAddress)
        vm.metadata.location?.city = normOrNil(loc.city)
        vm.metadata.location?.state = normOrNil(loc.state)
        vm.metadata.location?.country = normOrNil(loc.country)
    }

    // cp-2025-12-30(LOC-RESET-GPS)
    func resetLocationToGPS() {
        // Clear user selection and wipe all location fields
        selectedUserLocationID = nil
        vm.metadata.location = nil

        // Allow GPS to fill back in (if GPS exists)
        fillLocationFromGPS(overwrite: true)
    }

    // cp-2025-12-26-LOC-UI2(HELPERS)

    func reloadUserLocations() {
        userLocations = DMPPUserPreferences.load().userLocationsSortedForUI
    }

    var selectedUserLocation: DMPPUserLocation? {
        guard let id = selectedUserLocationID else { return nil }
        return userLocations.first(where: { $0.id == id })
    }

    // Kept (unused) in case you want it again later
    func applySelectedUserLocation(fillOnly: Bool) {
        guard let loc = selectedUserLocation else { return }

        if vm.metadata.location == nil { vm.metadata.location = DmpmsLocation() }

        func set(_ kp: WritableKeyPath<DmpmsLocation, String?>, _ value: String?) {
            let trimmed = (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }

            if fillOnly {
                let existing = (vm.metadata.location?[keyPath: kp] ?? "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                guard existing.isEmpty else { return }
            }

            vm.metadata.location?[keyPath: kp] = trimmed
        }

        set(\.shortName,      loc.shortName)
        set(\.description,    loc.description)
        set(\.streetAddress,  loc.streetAddress)
        set(\.city,           loc.city)
        set(\.state,          loc.state)
        set(\.country,        loc.country)
    }

    private func mapsURL() -> URL? {
        // Prefer GPS if present (most precise)
        if let gps = vm.metadata.gps {
            return URL(string: "http://maps.apple.com/?ll=\(gps.latitude),\(gps.longitude)")
        }

        // Fall back to typed address
        guard let loc = vm.metadata.location else { return nil }

        let parts = [
            loc.streetAddress,
            loc.city,
            loc.state,
            loc.country
        ]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }

        guard !parts.isEmpty else { return nil }

        let qRaw = parts.joined(separator: ", ")
        guard let q = qRaw.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return nil }

        return URL(string: "http://maps.apple.com/?q=\(q)")
    }

    private func openInMaps() {
        guard let url = mapsURL() else { return }
        NSWorkspace.shared.open(url)
    }

    func reloadAvailableTags() {
        availableTags = DMPPUserPreferences.load().availableTags
    }

    func bindingForTag(_ tag: String) -> Binding<Bool> {
        Binding(
            get: { vm.metadata.tags.contains(tag) },
            set: { isOn in
                if isOn {
                    if !vm.metadata.tags.contains(tag) { vm.metadata.tags.append(tag) }
                } else {
                    vm.metadata.tags.removeAll { $0 == tag }
                }
            }
        )
    }

    func shortNowStamp() -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: Date())
    }

    func performResetPeople(captureSnapshot: Bool) {
        if captureSnapshot {
            let note = "Before reset \(shortNowStamp())"
            capturePeopleSnapshot(note: note)
        }

        vm.metadata.peopleV2.removeAll()
        vm.reconcilePeopleV2Identities(identityStore: identityStore)
        vm.recomputeAgesForCurrentImage()
    }

    func capturePeopleSnapshot(note: String) {
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

    var orderedSnapshots: [DmpmsPeopleSnapshot] {
        vm.metadata.peopleV2Snapshots.sorted { $0.createdAtISO8601 > $1.createdAtISO8601 }
    }

    func restoreSnapshot(id: String) {
        guard let snap = vm.metadata.peopleV2Snapshots.first(where: { $0.id == id }) else { return }
        vm.metadata.peopleV2 = snap.peopleV2
        vm.reconcilePeopleV2Identities(identityStore: identityStore)
        vm.recomputeAgesForCurrentImage()
    }

    func deleteSnapshot(id: String) {
        vm.metadata.peopleV2Snapshots.removeAll { $0.id == id }
    }

    func updateSnapshotNote(id: String, note: String) {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let idx = vm.metadata.peopleV2Snapshots.firstIndex(where: { $0.id == id }) else { return }
        vm.metadata.peopleV2Snapshots[idx].note = trimmed
    }

    func rowLabel(for rowIndex: Int) -> String {
        switch rowIndex {
        case 0: return "Front"
        default: return "Row \(rowIndex + 1)"
        }
    }

    func nextPositionIndex(inRow rowIndex: Int) -> Int {
        let inRow = vm.metadata.peopleV2.filter { $0.rowIndex == rowIndex && $0.roleHint != "rowMarker" }
        return (inRow.map(\.positionIndex).max() ?? -1) + 1
    }

    func peopleLineAttributed(rowPeople: [DmpmsPersonInPhoto]) -> AttributedString {
        var line = AttributedString("")

        for (idx, person) in rowPeople.enumerated() {

            var namePart = AttributedString(person.shortNameSnapshot)

            if !person.isUnknown && person.identityID != nil {
                namePart.inlinePresentationIntent = .stronglyEmphasized
                namePart.foregroundColor = .primary
            } else {
                namePart.foregroundColor = .secondary
            }

            line.append(namePart)

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

    // Summary rows for current photo (non-markers), newest row first
    func peopleRowsForSummary() -> [(rowIndex: Int, people: [DmpmsPersonInPhoto])] {
        let sortedPeople = vm.metadata.peopleV2.sorted {
            if $0.rowIndex == $1.rowIndex { return $0.positionIndex < $1.positionIndex }
            return $0.rowIndex < $1.rowIndex
        }

        let nonMarkers = sortedPeople.filter { $0.roleHint != "rowMarker" }
        let grouped = Dictionary(grouping: nonMarkers, by: { $0.rowIndex })
        let rowIndexes = grouped.keys.sorted(by: >)

        return rowIndexes.map { r in
            let rowPeople = (grouped[r] ?? []).sorted { $0.positionIndex < $1.positionIndex }
            return (rowIndex: r, people: rowPeople)
        }
    }

    func peopleRowsForSnapshot(_ snap: DmpmsPeopleSnapshot) -> [(rowIndex: Int, line: String)] {
        let nonMarkers = snap.peopleV2.filter { $0.roleHint != "rowMarker" }
        let grouped = Dictionary(grouping: nonMarkers, by: { $0.rowIndex })
        let rowIndexes = grouped.keys.sorted(by: >)

        return rowIndexes.map { r in
            let rowPeople = (grouped[r] ?? []).sorted { $0.positionIndex < $1.positionIndex }
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
            return (rowIndex: r, line: line)
        }
    }

    func orderedChecklistPeople() -> [DMPPIdentityStore.PersonSummary] {
        let availablePeople: [DMPPIdentityStore.PersonSummary] =
            showAllPeopleInChecklist
            ? identityStore.peopleSortedForUI
            : identityStore.peopleAliveDuring(photoRange: vm.metadata.dateRange)

        guard !availablePeople.isEmpty else { return [] }

        // Base alpha sort
        let alpha = availablePeople.sorted {
            $0.shortName.localizedCaseInsensitiveCompare($1.shortName) == .orderedAscending
        }

        guard pinFavoritesToTop else { return alpha }

        let favs = alpha.filter { $0.isFavorite }
        let non = alpha.filter { !$0.isFavorite }
        return favs + non
    }

    func groupID(forIdentityID iid: String) -> String? {
        guard let ident = identityStore.identity(forIdentityID: iid) else { return nil }
        let pid = (ident.personID?.trimmingCharacters(in: .whitespacesAndNewlines))
            .flatMap { $0.isEmpty ? nil : $0 }
        return pid ?? ident.id
    }

    func bindingForPerson(_ person: DMPPIdentityStore.PersonSummary) -> Binding<Bool> {
        Binding(
            get: {
                vm.metadata.peopleV2.contains(where: { row in
                    if let iid = row.identityID, let gid = groupID(forIdentityID: iid) {
                        return gid == person.id
                    }
                    return row.shortNameSnapshot == person.shortName
                })
            },
            set: { newValue in
                if newValue {
                    let alreadySelected = vm.metadata.peopleV2.contains(where: { row in
                        guard let iid = row.identityID, let gid = groupID(forIdentityID: iid) else { return false }
                        return gid == person.id
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
                        guard let iid = row.identityID, let gid = groupID(forIdentityID: iid) else { return false }
                        return gid == person.id
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

    // MARK: Security-scoped access

    private func beginScopedAccess(to folder: URL) -> Bool {
        if activeScopedFolderURL == folder, activeScopedFolderOK { return true }
        endScopedAccess()

        let ok = folder.startAccessingSecurityScopedResource()
        activeScopedFolderURL = folder
        activeScopedFolderOK = ok
        return ok
    }

    private func endScopedAccess() {
        if let url = activeScopedFolderURL, activeScopedFolderOK {
            url.stopAccessingSecurityScopedResource()
        }
        activeScopedFolderURL = nil
        activeScopedFolderOK = false
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
        // Save current image metadata before switching folders / re-scanning.
        saveCurrentMetadata()

        guard beginScopedAccess(to: folder) else {
            continueErrorMessage = "Prep can’t access that folder. Please choose it again."
            showContinueError = true
            return
        }

        folderURL = folder

        let found: [URL] = includeSubfolders
            ? recursiveImageURLs(in: folder)
            : immediateImageURLs(in: folder)

        // Sort by relative path so subfolders feel stable/expected.
        let basePath = folder.path
        imageURLs = found.sorted {
            $0.path.replacingOccurrences(of: basePath + "/", with: "")
                < $1.path.replacingOccurrences(of: basePath + "/", with: "")
        }

        persistLastFolder(folder)

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
            let isFile = (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) ?? false
            guard isFile else { continue }
            guard dmppIsSupportedImageURL(url) else { continue }
            results.append(url)
        }
        return results
    }

    // MARK: Persistence (bookmark + toggles)

    private func persistLastFolder(_ url: URL) {
        let defaults = UserDefaults.standard

        defaults.set(includeSubfolders, forKey: kLastIncludeSubfolders)
        defaults.set(advanceToNextWithoutSidecar, forKey: kLastUnpreppedOnly)
        defaults.set(url.lastPathComponent, forKey: kLastFolderName)

        do {
            let data = try url.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            defaults.set(data, forKey: kLastFolderBookmark)
            lastFolderURL = url
        } catch {
            print("dMPP: Failed to persist folder bookmark: \(error)")
            lastFolderURL = nil
        }
    }

    private func loadPersistedLastFolder() {
        let defaults = UserDefaults.standard

        includeSubfolders = defaults.bool(forKey: kLastIncludeSubfolders)
        advanceToNextWithoutSidecar = defaults.bool(forKey: kLastUnpreppedOnly)

        guard let data = defaults.data(forKey: kLastFolderBookmark) else {
            lastFolderURL = nil
            return
        }

        var stale = false
        do {
            let url = try URL(
                resolvingBookmarkData: data,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &stale
            )
            lastFolderURL = url
            if stale { persistLastFolder(url) }
        } catch {
            print("dMPP: Failed to resolve folder bookmark: \(error)")
            lastFolderURL = nil
        }
    }

    // MARK: Last-folder “Continue” helpers

    private var lastFolderNameForUI: String {
        UserDefaults.standard.string(forKey: kLastFolderName)
        ?? lastFolderURL?.lastPathComponent
        ?? "Continue"
    }

    private var canContinueLastFolder: Bool {
        guard let url = lastFolderURL else { return false }

        // Quick existence check
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else {
            return false
        }

        // Optional: verify we can actually scope it (so button only shows when it will work)
        let ok = url.startAccessingSecurityScopedResource()
        if ok { url.stopAccessingSecurityScopedResource() }
        return ok
    }

    private func continueLastFolder() {
        guard let url = lastFolderURL else { return }
        loadImages(from: url) // loadImages handles scoping + error message
    }

    // MARK: UI helpers

    private var displayPathText: String {
        guard let folderURL else { return "" }

        if includeSubfolders, imageURLs.indices.contains(currentIndex) {
            let imageURL = imageURLs[currentIndex]
            let parent = imageURL.deletingLastPathComponent()

            if parent.path.hasPrefix(folderURL.path) {
                let rel = parent.path
                    .replacingOccurrences(of: folderURL.path, with: "")
                    .trimmingCharacters(in: CharacterSet(charactersIn: "/"))

                if rel.isEmpty {
                    return folderURL.lastPathComponent
                } else {
                    return "\(folderURL.lastPathComponent) ▸ \(rel.replacingOccurrences(of: "/", with: " ▸ "))"
                }
            }
        }

        let parts = folderURL.pathComponents
        return parts.suffix(3).joined(separator: " / ")
    }

    private func nextPositionIndex(inRow rowIndex: Int) -> Int {
        guard let vm else { return 0 }
        let inRow = vm.metadata.peopleV2.filter { $0.rowIndex == rowIndex && $0.roleHint != "rowMarker" }
        return (inRow.map(\.positionIndex).max() ?? -1) + 1
    }

    // MARK: Row sync (per-image)

    // cp-2025-12-21-ROW-SYNC
    private func syncActiveRowIndexFromCurrentPhoto() {
        guard let editorVM = self.vm else {
            activeRowIndex = 0
            return
        }

        let maxRow = editorVM.metadata.peopleV2.map(\.rowIndex).max() ?? 0
        activeRowIndex = maxRow
    }

    // MARK: Image navigation

    private func loadImage(at index: Int) {
        guard imageURLs.indices.contains(index) else { return }

        saveCurrentMetadata()

        currentIndex = index
        let url = imageURLs[index]

        // Load sidecar first (mutable so we can hydrate)
        var metadata = loadMetadata(for: url)

        // Hydrate GPS (if present)
        if let gps = DMPPPhotoLocationReader.readGPS(from: url) {
            metadata.gps = gps
        }

        let newVM = DMPPImageEditorViewModel(imageURL: url, metadata: metadata)

        newVM.wireAgeRefresh()
        newVM.stripMissingPeopleV2Identities(identityStore: .shared)
        newVM.reconcilePeopleV2Identities(identityStore: .shared)
        newVM.recomputeAgesForCurrentImage()

        vm = newVM
        loadedMetadataHash = metadataHash(newVM.metadata)
        syncActiveRowIndexFromCurrentPhoto()

        // Optional async reverse-geocode (only if location is still empty).
        if metadata.location == nil, let gps = metadata.gps {
            Task {
                if let loc = await DMPPPhotoLocationReader.reverseGeocode(gps) {
                    await MainActor.run {
                        // Don’t stomp if user already typed something
                        if self.vm?.metadata.location == nil {
                            self.vm?.metadata.location = loc
                            // NOTE: We intentionally do NOT update loadedMetadataHash here,
                            // so Save becomes enabled and/or auto-save-on-next will persist it.
                        }
                    }
                }
            }
        }
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

    /// Single source of truth: normalize peopleV2 (remove missing IDs, choose best identity version),
    /// then sync legacy people[] from peopleV2 when needed.
    private func normalizePeople(in metadata: inout DmpmsMetadata) {
        let store = DMPPIdentityStore.shared
        let photoEarliest = metadata.dateRange?.earliest

        metadata.peopleV2.removeAll { row in
            guard let id = row.identityID else { return false }
            return store.identity(withID: id) == nil
        }

        for i in metadata.peopleV2.indices {
            guard
                let currentID = metadata.peopleV2[i].identityID,
                let currentIdentity = store.identity(withID: currentID)
            else { continue }

            let pid = currentIdentity.personID ?? currentIdentity.id
            let versions = store.identityVersions(forPersonID: pid)
            guard !versions.isEmpty else { continue }

            let chosen = store.bestIdentityForPhoto(
                versions: versions,
                photoEarliestYMD: photoEarliest
            )

            metadata.peopleV2[i].identityID = chosen.id
            metadata.peopleV2[i].shortNameSnapshot = chosen.shortName
            metadata.peopleV2[i].displayNameSnapshot = chosen.fullName
            metadata.peopleV2[i].ageAtPhoto = ageDescription(
                birthDateString: chosen.birthDate,
                range: metadata.dateRange
            )
        }

        metadata.syncLegacyPeopleFromPeopleV2IfNeeded()
    }

    private func saveCurrentMetadata() {
        guard let vm else { return }

        var metadataToSave = vm.metadata
        normalizePeople(in: &metadataToSave)
        vm.metadata = metadataToSave

        let url = sidecarURL(for: vm.imageURL)
        let newBaseline = metadataHash(metadataToSave)

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted]

            let data = try encoder.encode(metadataToSave)
            try data.write(to: url, options: .atomic)

            loadedMetadataHash = newBaseline
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

        // Location/GPS MUST affect save-dirty state
        if let gps = m.gps {
            h.combine(gps.latitude)
            h.combine(gps.longitude)
            h.combine(gps.altitudeMeters ?? 0)
        } else {
            h.combine("no-gps")
        }

        if let loc = m.location {
            h.combine(loc.streetAddress ?? "")
            h.combine(loc.city ?? "")
            h.combine(loc.state ?? "")
            h.combine(loc.country ?? "")
        } else {
            h.combine("no-location")
        }

        for t in m.tags.sorted() { h.combine(t) }

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
            // intentionally exclude ageAtPhoto (derived)
        }

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

    private func loadMetadata(for imageURL: URL) -> DmpmsMetadata {
        let sidecar = sidecarURL(for: imageURL)
        let fm = FileManager.default

        if fm.fileExists(atPath: sidecar.path) {
            do {
                let data = try Data(contentsOf: sidecar)
                var metadata = try JSONDecoder().decode(DmpmsMetadata.self, from: data)

                metadata.sourceFile = imageURL.lastPathComponent
                normalizePeople(in: &metadata)
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

    // MARK: Crop math helper (kept)

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

private func revealInFinder(_ url: URL) {
    NSWorkspace.shared.activateFileViewerSelecting([url])
}

// MARK: - Preview

#Preview {
    DMPPImageEditorView()
        .frame(width: 1000, height: 650)
}
