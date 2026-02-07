import SwiftUI
import AppKit
import Observation
import Foundation
import ImageIO
import UniformTypeIdentifiers

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
    @State private var exportFolderURL: URL? = nil
    @State private var showExportError: Bool = false
    @State private var exportErrorMessage: String = ""
    // [ARCH] User-facing warning when a selected folder is outside the Photo Library Folder
    @State private var folderPickerWarning: String? = nil
    // [LOCK] Warning-only soft lock UI
    @State private var softLockWarningText: String? = nil
    @State private var currentPhotoRelPathForLock: String? = nil
    // [LOCK] Heartbeat timer (updates our lock timestamp while we’re on a picture)
    @State private var softLockHeartbeatTimer: Timer? = nil

    // [ARCH] Access the chosen Photo Library Folder (archive root)
    @EnvironmentObject private var archiveStore: DMPPArchiveStore
    @EnvironmentObject private var identityStore: DMPPIdentityStore

    private let kLastFolderBookmark = "dmpp.lastFolderBookmark"
    private let kLastFolderName = "dmpp.lastFolderName"
    private let kLastIncludeSubfolders = "dmpp.lastIncludeSubfolders"
    private let kLastUnpreppedOnly = "dmpp.lastUnpreppedOnly"
    private let kExportFolderBookmark = "dmpp.exportFolderBookmark"
    private let kExportFolderName = "dmpp.exportFolderName"

    private var isSaveEnabled: Bool {
        guard let vm else { return false }
        guard let loadedMetadataHash else { return true }
        return metadataHash(vm.metadata) != loadedMetadataHash
    }

    // MARK: View

    var body: some View {
        VStack(spacing: 0) {
            toolbarView
            softLockBannerView
            Divider()
            mainContentView
        }
        .onAppear {
            loadPersistedLastFolder()
            loadPersistedExportFolder()
        }
        .onDisappear {
            // [ARCH] End security-scoped access
            endScopedAccess()

            // [LOCK] Best-effort cleanup when this window goes away
            stopSoftLockHeartbeat()

            if let root = archiveStore.archiveRootURL,
               let relPath = currentPhotoRelPathForLock {
                DMPPSoftLockService.removeLock(
                    root: root,
                    photoRelPath: relPath,
                    sessionID: DMPPSoftLockService.currentSessionID()
                )
            }
        }
        .alert("Export failed", isPresented: $showExportError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(exportErrorMessage)
        }
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

                if let folderPickerWarning, !folderPickerWarning.isEmpty {
                    Text(folderPickerWarning)
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .lineLimit(2)
                }

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
                HStack(spacing: 10) {

                    Button {
                        vm.deleteSelectedCrop()
                    } label: {
                        Text("Delete Crop")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color.red)
                            )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(nsColor: .windowBackgroundColor))
                    )
                    .padding(.top, -24)
                    .padding(.leading, 16)

                    Button {
                        exportSelectedCrop()
                    } label: {
                        Text("Export Crop")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    .buttonStyle(.bordered)
                    .help("Export the current crop as a new image file")
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(nsColor: .windowBackgroundColor))
                    )
                    .padding(.top, -24)
                    .padding(.leading, 6)
                }
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

            let canNavigateCrops = vm.metadata.virtualCrops.count > 1

            Button("Previous Crop") { vm.selectPreviousCrop() }
                .disabled(!canNavigateCrops)

            Button("Next Crop") { vm.selectNextCrop() }
                .disabled(!canNavigateCrops)

            Button("Next Picture") { goToNextImage() }
                .disabled(!canGoToNext)
                .help("Changes are saved automatically.")
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.thinMaterial)
    }

    // [LOCK] Full-width warning banner (rendered BELOW toolbar so we don’t break toolbar layout)
    @ViewBuilder
    private var softLockBannerView: some View {
        if let softLockWarningText, !softLockWarningText.isEmpty {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.headline)

                Text(softLockWarningText)
                    .font(.callout.weight(.semibold))
                    .lineLimit(2)

                Spacer(minLength: 8)

                Button("Dismiss") {
                    self.softLockWarningText = nil
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(
                Rectangle()
                    .fill(Color.yellow)
            )
            .overlay(
                Rectangle()
                    .stroke(Color.orange.opacity(0.65), lineWidth: 1)
            )
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.2), value: softLockWarningText)
        }
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

// ================================================================
// [ARCH] URL helper: is `self` inside `ancestor`?
// Must be at FILE SCOPE (outside any struct/class).
// ================================================================
private extension URL {
    func isDescendant(of ancestor: URL) -> Bool {
        let me = self.standardizedFileURL.resolvingSymlinksInPath().path
        let root = ancestor.standardizedFileURL.resolvingSymlinksInPath().path

        // Ensure root path ends with "/" so "/Photos" doesn't match "/PhotosOld"
        let rootWithSlash = root.hasSuffix("/") ? root : (root + "/")
        return me.hasPrefix(rootWithSlash)
    }
}

// MARK: - Left Pane

/// [DMPP-SI-LEFT] Crops + image preview + crop controls (chips above preview).
struct DMPPCropEditorPane: View {

    @Environment(\.openSettings) private var openSettings

    /// For the crop editor we only need read access to the view model.
    var vm: DMPPImageEditorViewModel

    // MARK: - [HEADSHOT-PICKER] People list for Headshot menu (from current photo)

    private struct HeadshotPersonOption: Identifiable {
        let personID: String
        let label: String
        var id: String { personID }
    }

    /// People currently checked in this photo (unique by personID).
    private var peopleInPhotoForHeadshots: [HeadshotPersonOption] {
        let candidates: [HeadshotPersonOption] = vm.metadata.peopleV2
            .filter { !$0.isUnknown }
            .compactMap { row in
                guard let pid = row.personID, !pid.isEmpty else { return nil }
                let name = row.shortNameSnapshot.trimmingCharacters(in: .whitespacesAndNewlines)
                return HeadshotPersonOption(personID: pid, label: name.isEmpty ? "Unnamed" : name)
            }

        // De-dupe by personID (keep first)
        var seen = Set<String>()
        let unique = candidates.filter { seen.insert($0.personID).inserted }

        // Sort alphabetically for menu friendliness.
        return unique.sorted { $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending }
    }

    private var hasAnyPeopleForHeadshots: Bool {
        !peopleInPhotoForHeadshots.isEmpty
    }

    /// Convenience accessor: current saved custom presets.
    /// [PREFS-REFRESH] Tie to refresh token so Menu items update after Settings edits.
    private var customPresets: [DMPPUserPreferences.CustomCropPreset] {
        _ = customPresetsRefreshToken
        return DMPPUserPreferences
            .load()
            .customCropPresets
            .sorted { $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending }
    }

    // [PREFS-REFRESH] Forces the New Crop menu to rebuild after Settings changes.
    @State private var customPresetsRefreshToken: Int = 0

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

    // MARK: - Titles

    private func headshotPersonLabel(for personID: String?) -> String {
        guard let personID, !personID.isEmpty else { return "Unlinked" }
        if let match = peopleInPhotoForHeadshots.first(where: { $0.personID == personID }) {
            return match.label
        }
        // Person might not be checked anymore; keep it readable.
        return "Person \(personID.prefix(6))…"
    }

    private func headshotVariantLabel(_ v: VirtualCrop.HeadshotVariant?) -> String {
        switch v {
        case .some(.full):  return "Full"
        case .some(.tight): return "Tight"
        case .none:         return "Headshot"
        }
    }

    /// Chip title shown above preview.
    /// - Headshots: "Full Headshot: Dan"
    /// - Custom preset matches: "Weird (12:5)"
    private func cropTabTitle(for crop: VirtualCrop) -> String {

        // Headshot special-case (your requested wording/order)
        if crop.kind == .headshot {
            let v = headshotVariantLabel(crop.headshotVariant)
            let name = headshotPersonLabel(for: crop.headshotPersonID)
            return "\(v) Headshot: \(name)"
        }

        let base = vm.cropButtonTitle(for: crop)

        // Only attempt custom matching for real ratios (not freeform/custom)
        let ratio = crop.aspectRatio
        if ratio == "custom" || ratio.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return base
        }

        let cropLabel = crop.label.trimmingCharacters(in: .whitespacesAndNewlines)

        // Find a matching custom preset by label + ratio
        for preset in customPresets {
            let presetLabel = preset.label.trimmingCharacters(in: .whitespacesAndNewlines)
            let presetRatio = "\(preset.aspectWidth):\(preset.aspectHeight)"

            if presetLabel == cropLabel && presetRatio == ratio {
                return "\(presetLabel) (\(ratio))"
            }
        }

        return base
    }

    // MARK: - Sorting (chips)

    private enum ChipGroup: Int {
        case original = 0
        case freeform = 1
        case landscape = 2
        case portrait = 3
        case square = 4
        case otherStandard = 5
        case customPreset = 6
        case headshotFull = 7
        case headshotTight = 8
        case headshotOther = 9
    }

    private func group(for crop: VirtualCrop) -> ChipGroup {
        if crop.kind == .headshot {
            switch crop.headshotVariant {
            case .some(.full):  return .headshotFull
            case .some(.tight): return .headshotTight
            default:            return .headshotOther
            }
        }

        let t = vm.cropButtonTitle(for: crop)

        if t == "Original" { return .original }
        if t == "Freeform" { return .freeform }
        if t.hasPrefix("Landscape ") { return .landscape }
        if t.hasPrefix("Portrait ") { return .portrait }
        if t.hasPrefix("Square ") { return .square }

        if crop.sourceCustomPresetID != nil { return .customPreset }

        return .otherStandard
    }

    private func sortedCropsForChips(_ crops: [VirtualCrop]) -> [VirtualCrop] {
        crops.sorted { a, b in
            let ga = group(for: a).rawValue
            let gb = group(for: b).rawValue
            if ga != gb { return ga < gb }

            // Within group: alphabetical by displayed title
            let ta = cropTabTitle(for: a)
            let tb = cropTabTitle(for: b)
            return ta.localizedCaseInsensitiveCompare(tb) == .orderedAscending
        }
    }

    // MARK: - [HEADSHOT] Duplicate prevention helpers (menu)

    private func hasHeadshot(for personID: String, variant: VirtualCrop.HeadshotVariant) -> Bool {
        vm.metadata.virtualCrops.contains { crop in
            crop.kind == .headshot &&
            crop.headshotVariant == variant &&
            crop.headshotPersonID == personID
        }
    }

    private func canAddHeadshot(for personID: String, variant: VirtualCrop.HeadshotVariant) -> Bool {
        // Single place to change if you ever allow multiples per person later.
        return !hasHeadshot(for: personID, variant: variant)
    }

    // MARK: - View

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            headerChipsAndMenu

            // Preview + overlay + crop size slider (unchanged)
            HStack(alignment: .center, spacing: 12) {

                if let nsImage = vm.nsImage, let selectedCrop = vm.selectedCrop {
                    ZStack {
                        GeometryReader { geo in
                            ZStack {
                                Image(nsImage: nsImage)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: geo.size.width, height: geo.size.height)

                                let isHeadshot = (selectedCrop.kind == .headshot)
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
                    .overlay(alignment: .bottomTrailing) {
                        cropSizePill(nsImage: nsImage, cropRect: selectedCrop.rect)
                            .padding(10)
                    }
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
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .frame(width: 60)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .dmppPreferencesChanged)) { _ in
            customPresetsRefreshToken &+= 1
        }
    }

    // MARK: - Header (chips + menu)

    private var headerChipsAndMenu: some View {
        let allCrops = vm.metadata.virtualCrops
        let crops = sortedCropsForChips(allCrops)

        return HStack(alignment: .top, spacing: 12) {

            if crops.isEmpty {
                Text("No crops defined. Use “New Crop” to add one.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                FlowLayout(spacing: 8) {
                    ForEach(crops) { crop in
                        CropChipButton(
                            title: cropTabTitle(for: crop),
                            isSelected: crop.id == cropPickerSelection.wrappedValue
                        ) {
                            cropPickerSelection.wrappedValue = crop.id
                        }
                        .help(vm.cropButtonHelp(for: crop) ?? "")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Menu("New Crop") {
                // ---------------------------------------------------------
                // Freeform
                // ---------------------------------------------------------
                Button("Freeform") { vm.addFreeformCrop() }

                // ---------------------------------------------------------
                // Headshot (Full / Tight)
                // ---------------------------------------------------------
                Menu("Headshot") {

                    Menu("Full") {
                        if peopleInPhotoForHeadshots.isEmpty {
                            Text("Add people to this photo first")
                        } else {
                            ForEach(peopleInPhotoForHeadshots) { p in
                                Button(p.label) {
                                    vm.addHeadshotCrop(variant: .full, personID: p.personID)
                                }
                                .disabled(!canAddHeadshot(for: p.personID, variant: .full))
                            }
                        }
                    }
                    .disabled(!hasAnyPeopleForHeadshots)

                    Menu("Tight") {
                        if peopleInPhotoForHeadshots.isEmpty {
                            Text("Add people to this photo first")
                        } else {
                            ForEach(peopleInPhotoForHeadshots) { p in
                                Button(p.label) {
                                    vm.addHeadshotCrop(variant: .tight, personID: p.personID)
                                }
                                .disabled(!canAddHeadshot(for: p.personID, variant: .tight))
                            }
                        }
                    }
                    .disabled(!hasAnyPeopleForHeadshots)
                }
                .disabled(!hasAnyPeopleForHeadshots)
                .help(hasAnyPeopleForHeadshots
                      ? ""
                      : "Add at least one person in the People section to enable headshots.")

                // ---------------------------------------------------------
                // Landscape
                // ---------------------------------------------------------
                Menu("Landscape") {
                    Button("3:2 (4×6, 8×12…)") { vm.addPresetLandscape3x2() }
                        .disabled(vm.hasPresetLandscape3x2)

                    Button("4:3 (18×24…)") { vm.addPresetLandscape4x3() }
                        .disabled(vm.hasPresetLandscape4x3)

                    Button("5:4 (4×5, 8×10…)") { vm.addPresetLandscape5x4() }
                        .disabled(vm.hasPresetLandscape5x4)

                    Button("7:5 (5×7…)") { vm.addPresetLandscape7x5() }
                        .disabled(vm.hasPresetLandscape7x5)

                    Button("14:11 (11×14…)") { vm.addPresetLandscape14x11() }
                        .disabled(vm.hasPresetLandscape14x11)

                    Button("16:9") { vm.addPresetLandscape16x9() }
                        .disabled(vm.hasPresetLandscape16x9)
                }

                // ---------------------------------------------------------
                // Original
                // ---------------------------------------------------------
                Button("Original (full image)") { vm.addPresetOriginalCrop() }
                    .disabled(vm.hasPresetOriginal)

                // ---------------------------------------------------------
                // Portrait
                // ---------------------------------------------------------
                Menu("Portrait") {
                    Button("2:3 (4×6, 8×12…)") { vm.addPresetPortrait2x3() }
                        .disabled(vm.hasCrop(aspectWidth: 2, aspectHeight: 3))

                    Button("3:4 (18×24…)") { vm.addPresetPortrait3x4() }
                        .disabled(vm.hasCrop(aspectWidth: 3, aspectHeight: 4))

                    Button("4:5 (4×5, 8×10…)") { vm.addPresetPortrait4x5() }
                        .disabled(vm.hasCrop(aspectWidth: 4, aspectHeight: 5))

                    Button("5:7 (5×7…)") { vm.addPresetPortrait5x7() }
                        .disabled(vm.hasCrop(aspectWidth: 5, aspectHeight: 7))

                    Button("11:14 (11×14…)") { vm.addPresetPortrait11x14() }
                        .disabled(vm.hasCrop(aspectWidth: 11, aspectHeight: 14))

                    Button("9:16") { vm.addPresetPortrait9x16() }
                        .disabled(vm.hasPresetPortrait9x16)
                }

                // ---------------------------------------------------------
                // Square
                // ---------------------------------------------------------
                Button("Square 1:1") { vm.addPresetSquare1x1() }
                    .disabled(vm.hasPresetSquare1x1)

                // ---------------------------------------------------------
                // Custom Presets
                // ---------------------------------------------------------
                Menu("Custom Presets") {
                    if customPresets.isEmpty {
                        Text("No custom presets yet")
                    } else {
                        ForEach(customPresets) { preset in
                            let presetIDString = preset.id.uuidString
                            let presetRatio = "\(preset.aspectWidth):\(preset.aspectHeight)"

                            // Prevent duplicates using durable link first.
                            let alreadyExists = vm.metadata.virtualCrops.contains { crop in
                                if crop.sourceCustomPresetID == presetIDString { return true }
                                return crop.aspectRatio == presetRatio && crop.label == preset.label
                            }

                            Button("\(preset.label) (\(preset.aspectWidth):\(preset.aspectHeight))") {
                                vm.addCrop(fromCustomPreset: preset)
                            }
                            .disabled(alreadyExists)
                        }
                    }

                    Divider()

                    Button("Manage Custom Presets…") { openSettings() }
                }
            }
            .padding(.top, 2)
        }
    }

    // MARK: - Chip UI

    private struct CropChipButton: View {
        let title: String
        let isSelected: Bool
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                Text(title)
                    .font(.callout)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false) // prevents “overlap squeeze”
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.18)
                                     : Color.secondary.opacity(0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(isSelected ? Color.accentColor.opacity(0.55)
                                             : Color.secondary.opacity(0.25),
                                  lineWidth: 1)
            )
        }
    }

    // MARK: - Wrapping layout (chips)

    private struct FlowLayout: Layout {
        var spacing: CGFloat = 8

        func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
            let maxWidth = proposal.width ?? 600

            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0

            for s in subviews {
                let size = s.sizeThatFits(.unspecified)

                if x > 0, x + size.width > maxWidth {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }

                if x > 0 { x += spacing }
                x += size.width
                rowHeight = max(rowHeight, size.height)
            }

            return CGSize(width: maxWidth, height: y + rowHeight)
        }

        func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
            var x = bounds.minX
            var y = bounds.minY
            var rowHeight: CGFloat = 0

            for s in subviews {
                let size = s.sizeThatFits(.unspecified)

                if x > bounds.minX, x + size.width > bounds.maxX {
                    x = bounds.minX
                    y += rowHeight + spacing
                    rowHeight = 0
                }

                s.place(
                    at: CGPoint(x: x, y: y),
                    proposal: ProposedViewSize(width: size.width, height: size.height)
                )

                x += size.width + spacing
                rowHeight = max(rowHeight, size.height)
            }
        }
    }

    // MARK: - Existing helpers (unchanged)

    private func cropSizePill(nsImage: NSImage, cropRect: RectNormalized) -> some View {
        let px = cropPixelSize(nsImage: nsImage, cropRect: cropRect)
        let wPx = px?.w ?? 0
        let hPx = px?.h ?? 0

        let wIn = Double(wPx) / 300.0
        let hIn = Double(hPx) / 300.0

        let pxLine = "\(wPx) × \(hPx) px"
        let inLine = String(format: "max print size - %.1f × %.1f in", wIn, hIn)

        return VStack(alignment: .trailing, spacing: 2) {
            Text(pxLine)
            Text(inLine)
        }
        .font(.caption2)
        .foregroundStyle(.primary)
        .monospacedDigit()
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(.secondary.opacity(0.25))
        )
    }

    private func cropPixelSize(nsImage: NSImage, cropRect: RectNormalized) -> (w: Int, h: Int)? {
        // Prefer true pixel dimensions (not points)
        if let rep = nsImage.representations.first {
            let imgW = rep.pixelsWide
            let imgH = rep.pixelsHigh
            if imgW > 0, imgH > 0 {
                let w = max(0, Int((Double(imgW) * cropRect.width).rounded()))
                let h = max(0, Int((Double(imgH) * cropRect.height).rounded()))
                return (w, h)
            }
        }

        // Fallback: points-based (less accurate, but better than nothing)
        let imgW = Int(nsImage.size.width.rounded())
        let imgH = Int(nsImage.size.height.rounded())
        guard imgW > 0, imgH > 0 else { return nil }

        let w = max(0, Int((Double(imgW) * cropRect.width).rounded()))
        let h = max(0, Int((Double(imgH) * cropRect.height).rounded()))
        return (w, h)
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

    @EnvironmentObject private var identityStore: DMPPIdentityStore

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
                Button("Edit tags, people, and locations in Settings") { openSettings() }
                    .buttonStyle(.link)
                    .font(.caption)
                    .tint(.accentColor)
                    .padding(.top, 4)
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
            }
            .onChange(of: vm.metadata.sourceFile) { _, _ in
                syncSavedLocationSelectionForCurrentPhoto()
                selectedUserLocationID = nil
            }
            .onChange(of: gpsKey) { _, _ in
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

                // Saved-location picker (label on the left, no description shown under picker)
                HStack(alignment: .center, spacing: 10) {

                    Text("Saved locations:")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Picker("", selection: $selectedUserLocationID) {
                        Text("—").tag(UUID?.none)

                        ForEach(userLocations) { loc in
                            Text(loc.shortName.trimmingCharacters(in: .whitespacesAndNewlines))
                                .tag(Optional(loc.id))
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onChange(of: selectedUserLocationID) { _, newValue in
                        guard newValue != nil else { return }
                        applySelectedUserLocationOverwriteAll()
                    }

                    Button("Reset to GPS") {
                        resetLocationToGPS()
                    }
                    .buttonStyle(.bordered)
                }

                Divider().padding(.vertical, 2)

                // Per-photo editable fields

                // Row 1: Short Name (read-only) + Open in Maps
                HStack(alignment: .top, spacing: 10) {

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Short Name")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text((vm.metadata.location?.shortName ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                             ? "—"
                             : (vm.metadata.location?.shortName ?? "—"))
                        .frame(width: 160, alignment: .leading)
                        .foregroundStyle(.primary)
                    }

                    Spacer()

                    VStack(alignment: .leading, spacing: 4) {
                        Text("")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Button("Open in Maps") {
                            openInMaps()
                        }
                        .buttonStyle(.bordered)
                        .disabled(mapsURL() == nil)
                        .help(mapsURL() == nil ? "No GPS or address available to open in Maps." : "Open this location in Apple Maps.")
                    }
                }

                // Row 2: Description
                VStack(alignment: .leading, spacing: 4) {
                    Text("Description")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    TextField("", text: bindingLocation(\.description))
                }

                // Row 3: Street Address
                VStack(alignment: .leading, spacing: 4) {
                    Text("Street Address")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    TextField("", text: bindingLocation(\.streetAddress))
                }

                // Row 4: City / State / Country + Clear
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("City")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        TextField("", text: bindingLocation(\.city))
                            .frame(width: 160)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("State")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        TextField("", text: bindingLocation(\.state))
                            .frame(width: 40)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Country")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        TextField("", text: bindingLocation(\.country))
                            .frame(width: 100)
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
            VStack(alignment: .leading, spacing: 10) {

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

                let unknownTags = unknownTagsInCurrentFile()

                if !unknownTags.isEmpty {
                    Divider().padding(.vertical, 2)

                    Text("Tags in this file not in Settings")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(unknownTags, id: \.self) { t in
                            Text(t)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
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

    private func fillLocationFromGPS(overwrite: Bool) {
        guard let gps = vm.metadata.gps else { return }

        if !overwrite, vm.metadata.location != nil { return }

        Task {
            if let loc = await DMPPPhotoLocationReader.reverseGeocode(gps) {
                let prefs = DMPPUserPreferences.load()
                let match = prefs.matchingUserLocation(for: loc)

                await MainActor.run {
                    if !overwrite, vm.metadata.location != nil { return }

                    vm.metadata.location = loc

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

        vm.metadata.location?.shortName = normOrNil(loc.shortName)
        vm.metadata.location?.description = normOrNil(loc.description)
        vm.metadata.location?.streetAddress = normOrNil(loc.streetAddress)
        vm.metadata.location?.city = normOrNil(loc.city)
        vm.metadata.location?.state = normOrNil(loc.state)
        vm.metadata.location?.country = normOrNil(loc.country)
    }

    // cp-2025-12-30(LOC-RESET-GPS)
    func resetLocationToGPS() {
        selectedUserLocationID = nil
        vm.metadata.location = nil
        fillLocationFromGPS(overwrite: true)
    }

    func reloadUserLocations() {
        userLocations = DMPPUserPreferences.load().userLocationsSortedForUI
    }

    var selectedUserLocation: DMPPUserLocation? {
        guard let id = selectedUserLocationID else { return nil }
        return userLocations.first(where: { $0.id == id })
    }

    private func mapsURL() -> URL? {
        if let loc = vm.metadata.location {
            let parts = [
                loc.streetAddress,
                loc.city,
                loc.state,
                loc.country
            ]
                .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            if !parts.isEmpty {
                let qRaw = parts.joined(separator: ", ")
                guard let q = qRaw.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return nil }
                return URL(string: "http://maps.apple.com/?q=\(q)")
            }
        }

        if let gps = vm.metadata.gps {
            return URL(string: "http://maps.apple.com/?ll=\(gps.latitude),\(gps.longitude)")
        }

        return nil
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

    private func unknownTagsInCurrentFile() -> [String] {
        let knownLower = Set(availableTags.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() })

        let unknown = vm.metadata.tags
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .filter { !knownLower.contains($0.lowercased()) }

        var seen = Set<String>()
        var result: [String] = []
        for t in unknown {
            let k = t.lowercased()
            if !seen.contains(k) {
                seen.insert(k)
                result.append(t)
            }
        }
        return result.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
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
            note: trimmed,
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
        let pid = (ident.personID?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines))
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
                            personID: chosen.personID ?? person.id,
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
    // (Everything below here is unchanged from your version except for
    // being left as-is — your crop + metadata IO pipeline stays intact.)

    // MARK: - Export Crop

    private func exportSelectedCrop() {
        guard let vm else { return }
        guard let crop = vm.selectedCrop else { return }

        guard let destFolder = ensureExportFolder() else { return }

        do {
            try exportCrop(
                sourceImageURL: vm.imageURL,
                cropRect: crop.rect,
                cropLabel: crop.label,
                destinationFolder: destFolder
            )
        } catch {
            exportErrorMessage = error.localizedDescription
            showExportError = true
        }
    }

    private func ensureExportFolder() -> URL? {
        if let url = exportFolderURL, FileManager.default.fileExists(atPath: url.path) {
            return url
        }

        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose Export Folder"

        guard panel.runModal() == .OK, let url = panel.url else { return nil }

        persistExportFolder(url)
        exportFolderURL = url
        return url
    }

    private func persistExportFolder(_ url: URL) {
        let defaults = UserDefaults.standard
        defaults.set(url.lastPathComponent, forKey: kExportFolderName)

        do {
            let data = try url.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            defaults.set(data, forKey: kExportFolderBookmark)
        } catch {
            print("dMPP: Failed to persist export folder bookmark: \(error)")
        }
    }

    private func loadPersistedExportFolder() {
        let defaults = UserDefaults.standard
        guard let data = defaults.data(forKey: kExportFolderBookmark) else {
            exportFolderURL = nil
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
            exportFolderURL = url
            if stale { persistExportFolder(url) }
        } catch {
            print("dMPP: Failed to resolve export folder bookmark: \(error)")
            exportFolderURL = nil
        }
    }

    private func exportCrop(
        sourceImageURL: URL,
        cropRect: RectNormalized,
        cropLabel: String,
        destinationFolder: URL
    ) throws {

        let gotScope = destinationFolder.startAccessingSecurityScopedResource()
        defer { if gotScope { destinationFolder.stopAccessingSecurityScopedResource() } }

        guard let src = CGImageSourceCreateWithURL(sourceImageURL as CFURL, nil) else {
            throw NSError(domain: "dMPP.Export", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not open source image."])
        }
        guard let cgImage = CGImageSourceCreateImageAtIndex(src, 0, nil) else {
            throw NSError(domain: "dMPP.Export", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not decode source image."])
        }

        let imgW = cgImage.width
        let imgH = cgImage.height

        let x = Int((Double(imgW) * cropRect.x).rounded())
        let y = Int((Double(imgH) * cropRect.y).rounded())
        let w = Int((Double(imgW) * cropRect.width).rounded())
        let h = Int((Double(imgH) * cropRect.height).rounded())

        let cropBox = CGRect(x: x, y: y, width: w, height: h)
            .intersection(CGRect(x: 0, y: 0, width: imgW, height: imgH))

        guard cropBox.width > 1, cropBox.height > 1 else {
            throw NSError(domain: "dMPP.Export", code: 3, userInfo: [NSLocalizedDescriptionKey: "Crop rectangle is empty."])
        }

        guard let cropped = cgImage.cropping(to: cropBox) else {
            throw NSError(domain: "dMPP.Export", code: 4, userInfo: [NSLocalizedDescriptionKey: "Could not crop image."])
        }

        let ext = sourceImageURL.pathExtension.isEmpty ? "jpg" : sourceImageURL.pathExtension
        let base = sourceImageURL.deletingPathExtension().lastPathComponent

        let cleanLabel = sanitizeForFilename(cropLabel.isEmpty ? "Crop" : cropLabel)
        let outName = "\(base) — \(cleanLabel)"
        var outURL = destinationFolder
            .appendingPathComponent(outName)
            .appendingPathExtension(ext)

        outURL = uniqueURLIfNeeded(outURL)

        guard let utType = UTType(filenameExtension: ext.lowercased()) else {
            throw NSError(domain: "dMPP.Export", code: 5, userInfo: [NSLocalizedDescriptionKey: "Unknown file type: .\(ext)"])
        }

        guard let dest = CGImageDestinationCreateWithURL(outURL as CFURL, utType.identifier as CFString, 1, nil) else {
            throw NSError(
                domain: "dMPP.Export",
                code: 6,
                userInfo: [NSLocalizedDescriptionKey: "This Mac can’t export .\(ext) files yet (no ImageIO encoder)."]
            )
        }

        var options: [CFString: Any] = [:]
        if utType.conforms(to: .jpeg) || utType.conforms(to: .heic) {
            options[kCGImageDestinationLossyCompressionQuality] = 0.92
        }

        CGImageDestinationAddImage(dest, cropped, options as CFDictionary)
        guard CGImageDestinationFinalize(dest) else {
            throw NSError(domain: "dMPP.Export", code: 7, userInfo: [NSLocalizedDescriptionKey: "Failed to write the exported image file."])
        }
    }

    private func sanitizeForFilename(_ s: String) -> String {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        let bad = CharacterSet(charactersIn: "/\\:?%*|\"<>")
        let cleaned = trimmed
            .components(separatedBy: bad)
            .joined(separator: "-")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
        return cleaned.isEmpty ? "Crop" : cleaned
    }

    private func uniqueURLIfNeeded(_ url: URL) -> URL {
        let fm = FileManager.default
        if !fm.fileExists(atPath: url.path) { return url }

        let folder = url.deletingLastPathComponent()
        let base = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension

        var i = 2
        while true {
            let candidate = folder
                .appendingPathComponent("\(base) \(i)")
                .appendingPathExtension(ext)
            if !fm.fileExists(atPath: candidate.path) { return candidate }
            i += 1
        }
    }

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
        guard let root = archiveStore.archiveRootURL else {
            folderPickerWarning = "Set your Picture Library Folder first (File → Set Photo Library Folder…)."
            return
        }

        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
        panel.directoryURL = root

        if panel.runModal() == .OK, let url = panel.url {
            if !url.isDescendant(of: root) && url.standardizedFileURL != root.standardizedFileURL {
                folderPickerWarning = "Working folder must be inside your Picture Library Folder."
                return
            }

            folderPickerWarning = nil
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
        saveCurrentMetadata()

        guard let root = archiveStore.archiveRootURL else {
            continueErrorMessage = "Picture Library Folder is not set. Please set it first."
            showContinueError = true
            return
        }

        let rootPath = root.standardizedFileURL.resolvingSymlinksInPath().path
        let folderPath = folder.standardizedFileURL.resolvingSymlinksInPath().path
        let rootWithSlash = rootPath.hasSuffix("/") ? rootPath : (rootPath + "/")

        let folderIsWithinRoot = (folderPath == rootPath) || folderPath.hasPrefix(rootWithSlash)
        guard folderIsWithinRoot else {
            continueErrorMessage = "Working folder must be inside your Picture Library Folder."
            showContinueError = true
            return
        }

        let rel = (folderPath == rootPath) ? "" : String(folderPath.dropFirst(rootWithSlash.count))
        UserDefaults.standard.set(rel, forKey: "DMPP.LastWorkingFolderRelativePath.v1")
        UserDefaults.standard.synchronize()

        folderURL = folder

        let found: [URL] = includeSubfolders
            ? recursiveImageURLs(in: folder)
            : immediateImageURLs(in: folder)

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

        if let root = archiveStore.archiveRootURL,
           let rel = defaults.string(forKey: "DMPP.LastWorkingFolderRelativePath.v1") {

            let trimmed = rel.trimmingCharacters(in: .whitespacesAndNewlines)

            if trimmed.isEmpty {
                lastFolderURL = root
                return
            }

            let candidate = root.appendingPathComponent(trimmed, isDirectory: true)

            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: candidate.path, isDirectory: &isDir), isDir.boolValue {
                lastFolderURL = candidate
                return
            }
        }

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

    private var lastFolderNameForUI: String {
        if let rel = UserDefaults.standard.string(forKey: "DMPP.LastWorkingFolderRelativePath.v1"),
           !rel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return (rel as NSString).lastPathComponent
        }

        return UserDefaults.standard.string(forKey: kLastFolderName)
            ?? lastFolderURL?.lastPathComponent
            ?? "Continue"
    }

    private var canContinueLastFolder: Bool {
        guard let url = lastFolderURL else { return false }

        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else {
            return false
        }

        return true
    }

    private func continueLastFolder() {
        guard let url = lastFolderURL else { return }
        loadImages(from: url)
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

        stopSoftLockHeartbeat()
        saveCurrentMetadata()

        currentIndex = index
        let url = imageURLs[index]

        if let root = archiveStore.archiveRootURL,
           let relPath = relativePathUnderRoot(fileURL: url, rootURL: root) {

            if let prev = currentPhotoRelPathForLock, prev != relPath {
                DMPPSoftLockService.removeLock(
                    root: root,
                    photoRelPath: prev,
                    sessionID: DMPPSoftLockService.currentSessionID()
                )
            }
            currentPhotoRelPathForLock = relPath

            let session = DMPPSoftLockService.defaultSessionInfo()
            DMPPSoftLockService.pruneStaleLocks(root: root, photoRelPath: relPath)

            let others = DMPPSoftLockService.activeOtherSessions(
                root: root,
                photoRelPath: relPath,
                currentSessionID: session.sessionID
            )

            if let first = others.first {
                let minutes = minutesAgo(fromISO8601UTC: first.lastSeenUTC)
                if let minutes {
                    if others.count == 1 {
                        softLockWarningText = "Heads up: \(first.userDisplayName) on \(first.deviceName) may be editing this picture (active ~\(minutes)m ago). Suggest coordinating with them to work in different parts of the picture folder structure."
                    } else {
                        softLockWarningText = "Heads up: \(first.userDisplayName) and \(others.count - 1) other(s) may be editing this picture (active ~\(minutes)m ago). Suggest coordinating with them to work in different parts of the picture folder structure."
                    }
                } else {
                    if others.count == 1 {
                        softLockWarningText = "Heads up: \(first.userDisplayName) on \(first.deviceName) may be editing this picture. Suggest coordinating with them to work in different parts of the picture folder structure."
                    } else {
                        softLockWarningText = "Heads up: \(first.userDisplayName) and \(others.count - 1) other(s) may be editing this picture. Suggest coordinating with them to work in different parts of the picture folder structure."
                    }
                }
            } else {
                softLockWarningText = nil
            }

            do {
                try DMPPSoftLockService.upsertLock(root: root, photoRelPath: relPath, session: session)
            } catch {
                print("Soft lock upsert failed: \(error)")
            }
            startSoftLockHeartbeatIfPossible()

        } else {
            softLockWarningText = nil
            currentPhotoRelPathForLock = nil
        }

        var metadata = loadMetadata(for: url)

        if let gps = DMPPPhotoLocationReader.readGPS(from: url) {
            metadata.gps = gps
        }

        let newVM = DMPPImageEditorViewModel(
            imageURL: url,
            metadata: metadata,
            identityStore: identityStore
        )

        newVM.wireAgeRefresh()
        newVM.stripMissingPeopleV2Identities(identityStore: identityStore)
        newVM.reconcilePeopleV2Identities(identityStore: identityStore)
        newVM.recomputeAgesForCurrentImage()

        vm = newVM
        loadedMetadataHash = metadataHash(newVM.metadata)
        syncActiveRowIndexFromCurrentPhoto()

        if metadata.location == nil, let gps = metadata.gps {
            Task {
                if let loc = await DMPPPhotoLocationReader.reverseGeocode(gps) {
                    await MainActor.run {
                        if self.vm?.metadata.location == nil {
                            self.vm?.metadata.location = loc
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

    private func relativePathUnderRoot(fileURL: URL, rootURL: URL) -> String? {
        let rootPath = rootURL.standardizedFileURL.resolvingSymlinksInPath().path
        let filePath = fileURL.standardizedFileURL.resolvingSymlinksInPath().path
        let rootWithSlash = rootPath.hasSuffix("/") ? rootPath : (rootPath + "/")

        guard filePath.hasPrefix(rootWithSlash) else { return nil }
        return String(filePath.dropFirst(rootWithSlash.count))
    }

    private func minutesAgo(fromISO8601UTC iso: String) -> Int? {
        let fmt = ISO8601DateFormatter()
        guard let d = fmt.date(from: iso) else { return nil }
        let mins = Int(Date().timeIntervalSince(d) / 60.0)
        return max(0, mins)
    }

    private func startSoftLockHeartbeatIfPossible() {
        stopSoftLockHeartbeat()

        guard
            let root = archiveStore.archiveRootURL,
            let relPath = currentPhotoRelPathForLock
        else { return }

        softLockHeartbeatTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { _ in
            let session = DMPPSoftLockService.defaultSessionInfo()
            DMPPSoftLockService.pruneStaleLocks(root: root, photoRelPath: relPath)

            do {
                try DMPPSoftLockService.upsertLock(root: root, photoRelPath: relPath, session: session)
            } catch {
                print("Soft lock heartbeat upsert failed: \(error)")
            }
        }

        RunLoop.main.add(softLockHeartbeatTimer!, forMode: .common)
    }

    private func stopSoftLockHeartbeat() {
        softLockHeartbeatTimer?.invalidate()
        softLockHeartbeatTimer = nil
    }

    // MARK: Sidecar Read/Write

    private func sidecarURL(for imageURL: URL) -> URL {
        imageURL.appendingPathExtension("dmpms.json")
    }

    private func normalizePeople(in metadata: inout DmpmsMetadata) {
        let store = identityStore
        let photoEarliest = metadata.dateRange?.earliest

        func trimmed(_ s: String?) -> String? {
            guard let s else { return nil }
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            return t.isEmpty ? nil : t
        }

        func makeDisplayName(given: String, middle: String?, surname: String) -> String {
            if let m = trimmed(middle) {
                return "\(given) \(m) \(surname)"
            } else {
                return "\(given) \(surname)"
            }
        }

        func makeSortName(given: String, middle: String?, surname: String) -> String {
            if let m = trimmed(middle) {
                return "\(surname), \(given) \(m)"
            } else {
                return "\(surname), \(given)"
            }
        }

        let dt = metadata.dateTaken.trimmingCharacters(in: .whitespacesAndNewlines)
        let (photoStart, photoEnd): (Date?, Date?) = {
            if !dt.isEmpty {
                if dt.count == 10, let d = LooseYMD.parse(dt) { return (d, d) }
                return LooseYMD.parseRange(dt)
            }

            if let r = metadata.dateRange {
                let start = LooseYMD.parseRange(r.earliest).start
                let end   = LooseYMD.parseRange(r.latest).end
                return (start, end)
            }

            return (nil, nil)
        }()

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
            metadata.peopleV2[i].personID = chosen.personID ?? pid
            metadata.peopleV2[i].shortNameSnapshot = chosen.shortName
            metadata.peopleV2[i].displayNameSnapshot = chosen.fullName

            let given = chosen.givenName.trimmingCharacters(in: .whitespacesAndNewlines)
            let middle = trimmed(chosen.middleName)
            let surname = chosen.surname.trimmingCharacters(in: .whitespacesAndNewlines)

            let display = makeDisplayName(given: given, middle: middle, surname: surname)
            let sort = makeSortName(given: given, middle: middle, surname: surname)

            metadata.peopleV2[i].nameSnapshot = DmpmsNameSnapshot(
                given: given,
                middle: middle,
                surname: surname,
                display: display,
                sort: sort
            )

            let (b0, b1) = LooseYMD.birthRange(chosen.birthDate)
            metadata.peopleV2[i].ageAtPhoto = AgeAtPhoto.ageText(
                photoStart: photoStart,
                photoEnd: photoEnd,
                birthStart: b0,
                birthEnd: b1
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

    switch LooseYMD.validateNumericDateString(trimmed) {
    case .valid:
        return nil
    case .notApplicable:
        return nil
    case .invalid:
        return "Invalid date. Examples: 1976-07-04, 1976-07, 1976, 1970s, 1975-1977, 1975-12 to 1976-08"
    }
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

