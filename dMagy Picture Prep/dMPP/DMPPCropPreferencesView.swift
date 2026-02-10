// ================================================================
// DMPPCropPreferencesView.swift
// Purpose: Settings UI for managing crop presets, tags, locations, and people.
// ================================================================
//
// What this file owns (high level)
// - A multi-tab Settings view (Crops, Locations, People, Tags, General).
// - Crop defaults UI (built-in presets toggles).
// - Custom crop preset management:
//     - Portable registry (preferred): crops.json in the Picture Library Folder
//     - Legacy prefs (fallback): UserDefaults via DMPPUserPreferences
//
// Inputs
// - archiveStore (EnvironmentObject): provides the active Picture Library Folder (archive root)
// - cropStore   (EnvironmentObject): portable crop preset registry (crops.json)
// - tagStore    (StateObject): portable tag registry (tags.json)
// - locationStore (StateObject): portable location registry (locations.json)
// - prefs (State): cached UserDefaults preferences (DMPPUserPreferences.load())
//
// Outputs (side effects)
// - Writes UserDefaults when prefs change (default built-in crops; legacy custom presets fallback)
// - Writes portable registry files when an archive root is selected:
//     - Crops/crops.json via cropStore
//     - Tags/tags.json via tagStore
//     - Locations/locations.json via locationStore
//
// Data flow / source of truth rules
// - Built-in default crop selections live in UserDefaults (prefs.defaultCropPresets).
// - Custom crop presets should be portable when an archive root exists.
//   Legacy custom presets exist only as a fallback or migration source.
// - When a Picture Library Folder is selected, portable registries are configured
//   onAppear and whenever archiveStore.archiveRootURL changes.
//
// Debug notes
// - “DMPP Custom Presets source …” logs are only to confirm which source is active.
// ================================================================


import SwiftUI
import AppKit
import CryptoKit

// cp-2025-12-29-02(SETTINGS-TABS-HOSTFIX)

struct DMPPCropPreferencesView: View {

    // ============================================================
    // MARK: - State / Environment
    // ============================================================

    /// User-level preferences (loaded from UserDefaults).
    @State private var prefs: DMPPUserPreferences = .load()

    @State private var selectedLocationID: UUID? = nil
    @FocusState private var focusedField: FocusField?

    @EnvironmentObject var archiveStore: DMPPArchiveStore
    @EnvironmentObject var cropStore: DMPPCropStore

    @StateObject private var tagStore = DMPPTagStore()
    @StateObject private var locationStore = DMPPLocationStore()

    @State private var showLinkedFileDetails: Bool = false
    @State private var showLinkedTagsFileDetails: Bool = false

    // [CROPS-PORTABLE-DRAFT] Editable working copy for the Settings UI (portable registry)
    @State private var cropDraftPresets: [DMPPCropStore.Preset] = []

    // [CROPS-PORTABLE-LOCK] Prevent recursive onChange loops while persisting/sanitizing.
    @State private var isPersistingCropDraft: Bool = false

    // ============================================================
    // MARK: - [DEBUG] Custom Presets source indicator
    // ============================================================

    private var debugCustomPresetSourceLine: String {
        let portableCount = cropStore.presets.count
        let legacyCount = DMPPUserPreferences.load().customCropPresets.count
        return "DMPP Custom Presets source: portable=\(portableCount > 0 ? 1 : 0) legacy=\(legacyCount > 0 ? 1 : 0)"
    }

    
    private enum FocusField: Hashable {
        case locationShortName(UUID)
    }

    // ============================================================
    // MARK: - View
    // ============================================================

    var body: some View {
        TabView {

            // =====================================================
            // CROPS TAB
            // =====================================================
            VStack(alignment: .leading, spacing: 16) {

                VStack(alignment: .leading, spacing: 4) {
                    Text("Crop Presets")
                        .font(.title2.bold())
                    Text("Manage crops. Checked crops are created for pictures by default; all crops are available to add at any time.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 4)

                Divider()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        builtInPresetsSection
                        Divider()
                        customPresetsSection
                    }
                    .padding(.vertical, 4)
                }

                Spacer(minLength: 0)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .tabItem { Label("Crops", systemImage: "crop") }

            // =====================================================
            // LOCATIONS TAB
            // =====================================================
            VStack(alignment: .leading, spacing: 16) {

                VStack(alignment: .leading, spacing: 4) {
                    Text("Locations")
                        .font(.title2.bold())
                    Text("Manage saved locations that you can quickly apply to photos.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 4)

                Divider()

                VStack(alignment: .leading, spacing: 16) {
                    locationsSection
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                Spacer(minLength: 0)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .tabItem { Label("Locations", systemImage: "mappin.and.ellipse") }

            // =====================================================
            // PEOPLE TAB
            // =====================================================
            VStack(alignment: .leading, spacing: 16) {

                VStack(alignment: .leading, spacing: 4) {
                    Text("People")
                        .font(.title2.bold())
                    Text("Manage people and life events used for matching and age calculations.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 4)

                Divider()

                DMPPPeopleManagerView(host: .settingsTab)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .padding()
            .tabItem { Label("People", systemImage: "person.2") }

            // =====================================================
            // TAGS TAB
            // =====================================================
            VStack(alignment: .leading, spacing: 16) {

                VStack(alignment: .leading, spacing: 4) {
                    Text("Tags")
                        .font(.title2.bold())
                    Text("Manage the tags that appear as checkboxes in the editor.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 4)

                Divider()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        tagsSection
                    }
                    .padding(.vertical, 4)
                }

                Spacer(minLength: 0)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .tabItem { Label("Tags", systemImage: "tag") }

            // =====================================================
            // GENERAL TAB (Fingerprint + Copy chips)
            // =====================================================
            VStack(alignment: .leading, spacing: 16) {

                VStack(alignment: .leading, spacing: 4) {
                    Text("General")
                        .font(.title2.bold())
                    Text("See which Picture Library Folder is active and where shared registry data is stored.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 4)

                Divider()

                GroupBox("Picture Library Folder") {
                    VStack(alignment: .leading, spacing: 10) {

                        if let root = archiveStore.archiveRootURL {

                            VStack(alignment: .leading, spacing: 4) {
                                Text(root.lastPathComponent)
                                    .font(.headline)

                                Text(root.path)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                                    .lineLimit(2)
                            }

                            HStack(spacing: 12) {
                                Button("Change Picture Library Folder…") {
                                    archiveStore.promptForArchiveRoot()
                                }

                                Button("Show in Finder") {
                                    NSWorkspace.shared.activateFileViewerSelecting([root])
                                }
                            }
                            .padding(.top, 2)

                            DisclosureGroup(isExpanded: $showLinkedFileDetails) {
                                let portable = root.appendingPathComponent("dMagy Portable Archive Data", isDirectory: true)

                                VStack(alignment: .leading, spacing: 8) {
                                    Divider().padding(.vertical, 2)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Portable Archive Data (advanced)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)

                                        Text(portable.path)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                            .textSelection(.enabled)
                                            .lineLimit(2)
                                    }

                                    HStack(spacing: 12) {
                                        Button("Show Portable Data in Finder") {
                                            NSWorkspace.shared.activateFileViewerSelecting([portable])
                                        }

                                        Button("Copy Path") {
                                            NSPasteboard.general.clearContents()
                                            NSPasteboard.general.setString(portable.path, forType: .string)
                                        }
                                    }
                                }
                                .padding(.top, 6)
                            } label: {
                                Label("Linked files (advanced)", systemImage: "doc.text.magnifyingglass")
                                    .font(.callout.weight(.semibold))
                            }
                            .padding(.top, 6)

                        } else {

                            Text("No Picture Library Folder is selected yet.")
                                .foregroundStyle(.secondary)

                            Button("Select Picture Library Folder…") {
                                archiveStore.promptForArchiveRoot()
                            }
                            .padding(.top, 4)
                        }
                    }
                    .padding(10)
                }

                Spacer(minLength: 0)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .tabItem { Label("General", systemImage: "gearshape") }
        }
        .frame(
            minWidth: 820,
            idealWidth: 980,
            maxWidth: .infinity,
            minHeight: 760,
            idealHeight: 820,
            maxHeight: .infinity,
            alignment: .topLeading
        )

        // ============================================================
        // MARK: - Persistence hooks
        // ============================================================

        // [PREFS-SAVE] Save when built-in defaults change
        .onChange(of: prefs.defaultCropPresets) { _, _ in
            prefs.save()
        }

        // [PREFS-SAVE] Save when legacy custom presets change (only edited when NO archive root)
        .onChange(of: prefs.customCropPresets) { _, _ in
            prefs.save()
        }

        // ============================================================
        // MARK: - Lifecycle / Root switching
        // ============================================================

        .onAppear {
            configureForCurrentArchiveRoot()
        }
        .onChange(of: archiveStore.archiveRootURL) { _, _ in
            configureForCurrentArchiveRoot()
        }

        // Tags + Locations portable write-back (unchanged)
        .onChange(of: prefs.availableTags) { _, _ in
            persistPrefsTagsToPortable()
        }
        .onChange(of: prefs.userLocations) { _, _ in
            persistPrefsLocationsToPortable()
        }
    }

    // ============================================================
    // MARK: - [ARCH-CONFIG] Configure stores for current archive root
    // ============================================================

    private func configureForCurrentArchiveRoot() {

        // Reload prefs (keeps Settings window honest if other screens changed UserDefaults)
        prefs = DMPPUserPreferences.load()

        let root = archiveStore.archiveRootURL

        // -------------------------------
        // TAGS
        // -------------------------------
        tagStore.configureForArchiveRoot(root, fallbackTags: prefs.availableTags)
        tagStore.migrateFromLegacyPrefsIfNeeded(legacyTags: prefs.availableTags)
        syncTagsFromPortableIntoPrefs()

        // -------------------------------
        // LOCATIONS
        // -------------------------------
        locationStore.configureForArchiveRoot(root, fallbackLocations: prefs.userLocations)
        syncLocationsFromPortableIntoPrefs()

        // -------------------------------
        // CROPS (portable registry)
        // -------------------------------
        guard let root else {
            // No archive root: portable registries are unavailable.
            // Show legacy custom presets editor only.
            cropDraftPresets = []
            return
        }

        // 1) Load portable presets (or seed empty)
        cropStore.configureForArchiveRoot(root, fallbackPresets: [])

        // 2) One-time migration from legacy prefs if portable is empty
        //    (this function also clears legacy to prevent “portable=1 legacy=1” forever)
        cropStore.migrateLegacyPrefsIfNeeded(legacyPresets: prefs.customCropPresets)

        // 3) Refresh the UI draft from portable truth
        cropDraftPresets = cropStore.presets

        // Optional: if you want the debug line to reflect reality immediately
        // (not required, but keeps the Settings window consistent)
        prefs = DMPPUserPreferences.load()
    }


    private func configureCropsForCurrentRoot() {

        // No root => portable not available; UI will show legacy editor
        guard let root = archiveStore.archiveRootURL else {
            cropDraftPresets = []
            return
        }

        // Ensure store is pointed at root and has current file loaded
        cropStore.configureForArchiveRoot(root, fallbackPresets: nil)

        // Merge legacy prefs into portable, then clear legacy to stop “portable=1 legacy=1”.
        // IMPORTANT: only call ONE migration method (the merge+clear one).
        let legacy = DMPPUserPreferences.load().customCropPresets
        cropStore.mergeLegacyPrefsIntoPortableThenClear(legacyPresets: legacy)

        // Pull portable truth into our UI draft
        cropDraftPresets = cropStore.presets
    }

    // ============================================================
    // MARK: - General tab helpers
    // ============================================================

    private func copyToClipboard(_ s: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(s, forType: .string)
    }

    private func fingerprint(for url: URL) -> String {
        let input = Data(url.path.utf8)
        let digest = SHA256.hash(data: input)
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        return String(hex.prefix(12)).uppercased()
    }

    // ============================================================
    // MARK: - Tags portable sync
    // ============================================================

    private func syncTagsFromPortableIntoPrefs() {
        tagStore.configureForArchiveRoot(
            archiveStore.archiveRootURL,
            fallbackTags: prefs.availableTags
        )

        let portable = tagStore.tags
        guard !portable.isEmpty else { return }

        if prefs.availableTags != portable {
            prefs.availableTags = portable
        }
    }

    private func persistPrefsTagsToPortable() {
        tagStore.persistTagsFromUI(prefs.availableTags)

        let portable = tagStore.tags
        if !portable.isEmpty, prefs.availableTags != portable {
            prefs.availableTags = portable
        }
    }

    // ============================================================
    // MARK: - Locations portable sync
    // ============================================================

    private func syncLocationsFromPortableIntoPrefs() {
        locationStore.configureForArchiveRoot(
            archiveStore.archiveRootURL,
            fallbackLocations: prefs.userLocations
        )

        let portable = locationStore.locations
        guard !portable.isEmpty else { return }

        if prefs.userLocations != portable {
            prefs.userLocations = portable
        }
    }

    private func persistPrefsLocationsToPortable() {
        locationStore.persistLocationsFromUI(prefs.userLocations)

        let portable = locationStore.locations
        if !portable.isEmpty, prefs.userLocations != portable {
            prefs.userLocations = portable
        }
    }

    // ============================================================
    // MARK: - Shared UI bits
    // ============================================================

    @ViewBuilder
    private func fingerprintChip(label: String, value: String) -> some View {
        HStack(spacing: 6) {
            Text(label + ":")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.caption2.monospaced())
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                )
                .textSelection(.enabled)
        }
    }

    @ViewBuilder
    private func linkedTagsFilePanel() -> some View {
        GroupBox {
            DisclosureGroup(isExpanded: $showLinkedTagsFileDetails) {

                VStack(alignment: .leading, spacing: 10) {

                    if let url = tagStore.tagsFileURL() {

                        HStack(spacing: 10) {
                            Image(systemName: "touchid")
                                .foregroundStyle(.secondary)

                            Text(url.lastPathComponent)
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(.quaternary.opacity(0.6))
                                .clipShape(Capsule())

                            Spacer()
                        }

                        Text(url.path)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .lineLimit(2)

                        HStack(spacing: 10) {
                            Button("Copy file name") {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(url.lastPathComponent, forType: .string)
                            }

                            Button("Copy full path") {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(url.path, forType: .string)
                            }

                            Button("Show in Finder") {
                                NSWorkspace.shared.activateFileViewerSelecting([url])
                            }
                        }
                        .controlSize(.small)

                    } else {
                        Text("Picture Library Folder isn’t configured yet, so the linked file can’t be shown.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 8)

            } label: {
                Label("Linked file (advanced)", systemImage: "doc.text.magnifyingglass")
                    .font(.callout.weight(.semibold))
            }
            .padding(8)
        }
    }

    // ============================================================
    // MARK: - Sections (Crops tab)
    // ============================================================

    private struct BuiltInPresetRow: Identifiable {
        let id: DMPPUserPreferences.CropPresetID
        let title: String
        let education: String
    }

    private var builtInPresetRowsSorted: [BuiltInPresetRow] {
        let rows: [BuiltInPresetRow] = [
            .init(id: .headshot8x10,   title: "Headshot 8×10",         education: "Portrait 4:5 with headshot guides"),
            .init(id: .original,       title: "Original (full image)", education: "Full frame, aspect from actual pixels."),

            .init(id: .landscape14x11, title: "Landscape 14:11",       education: "Includes print sizes 11×14…"),
            .init(id: .landscape16x9,  title: "Landscape 16:9",        education: "Typical TV / display aspect."),
            .init(id: .landscape3x2,   title: "Landscape 3:2",         education: "Includes print sizes 4×6, 8×12…"),
            .init(id: .landscape4x3,   title: "Landscape 4:3",         education: "Includes print sizes 18×24…"),
            .init(id: .landscape5x4,   title: "Landscape 5:4",         education: "Includes print sizes 4×5, 8×10…"),
            .init(id: .landscape7x5,   title: "Landscape 7:5",         education: "Includes print sizes 5×7…"),

            .init(id: .portrait11x14,  title: "Portrait 11:14",        education: "Includes print sizes 11×14…"),
            .init(id: .portrait2x3,    title: "Portrait 2:3",          education: "Includes print sizes 4×6, 8×12…"),
            .init(id: .portrait3x4,    title: "Portrait 3:4",          education: "Includes print sizes 18×24…"),
            .init(id: .portrait4x5,    title: "Portrait 4:5",          education: "Includes print sizes 4×5, 8×10…"),
            .init(id: .portrait5x7,    title: "Portrait 5:7",          education: "Includes print sizes 5×7…"),
            .init(id: .portrait9x16,   title: "Portrait 9:16",         education: "Vertical screen"),

            .init(id: .square1x1,      title: "Square 1:1",            education: "Square crops (social, grids, etc.)"),
        ]

        return rows.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    private var builtInPresetsSection: some View {
        VStack(alignment: .leading, spacing: 8) {

            Text("Standard crops")
                .font(.headline)

            VStack(alignment: .leading, spacing: 6) {

                HStack {
                    Spacer()
                    Text("Default")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .frame(width: 70, alignment: .center)
                }
                .padding(.bottom, 2)

                ForEach(builtInPresetRowsSorted) { row in
                    builtInRow(id: row.id, title: row.title, subtitle: row.education)
                }
            }
            .frame(maxWidth: 450, alignment: .leading)
            .padding(.top, 4)
        }
    }

    private func builtInRow(
        id: DMPPUserPreferences.CropPresetID,
        title: String,
        subtitle: String
    ) -> some View {

        let isOnBinding = Binding<Bool>(
            get: { prefs.defaultCropPresets.contains(id) },
            set: { newValue in
                if newValue {
                    if !prefs.defaultCropPresets.contains(id) {
                        prefs.defaultCropPresets.append(id)
                    }
                } else {
                    prefs.defaultCropPresets.removeAll { $0 == id }
                }
            }
        )

        return HStack(alignment: .firstTextBaseline) {
            Text("\(title) — \(subtitle)")
                .frame(maxWidth: .infinity, alignment: .leading)

            Toggle("", isOn: isOnBinding)
                .labelsHidden()
                .toggleStyle(.checkbox)
                .frame(width: 70, alignment: .center)
        }
        .padding(.vertical, 2)
    }

    // ============================================================
    // MARK: - Custom presets section (portable-first)
    // ============================================================

    private var customPresetsSection: some View {
        VStack(alignment: .leading, spacing: 8) {

            Text("Custom crops")
                .font(.headline)

            // No root => show legacy editor
            if archiveStore.archiveRootURL == nil {

                Text("Select a Picture Library Folder to manage portable custom crops.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)

                legacyCustomPresetsEditor

            } else {

                // Portable editor (crops.json)
                if cropDraftPresets.isEmpty {
                    Text("No custom presets yet. Click “Add Crop” to create one.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                } else {
                    portableCustomPresetsEditor
                }

                Button {
                    addBlankPortableCropPreset()
                } label: {
                    Label("Add Crop", systemImage: "plus")
                }
                .padding(.top, 6)
            }
        }
    }

    private var portableCustomPresetsEditor: some View {
        VStack(spacing: 8) {

            HStack {
                Text("Crop name")
                    .font(.caption.bold())
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("Width : Height")
                    .font(.caption.bold())
                    .frame(width: 110, alignment: .leading)

                Text("Default")
                    .font(.caption.bold())
                    .frame(width: 70, alignment: .center)

                Spacer().frame(width: 24)
            }
            .padding(.bottom, 2)

            Divider()

            ForEach($cropDraftPresets) { $p in
                HStack(alignment: .center, spacing: 8) {

                    TextField("Preset name", text: $p.label)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 4) {
                        TextField("W", value: $p.aspectWidth, formatter: NumberFormatter())
                            .frame(width: 40)
                            .textFieldStyle(.roundedBorder)

                        Text(":")

                        TextField("H", value: $p.aspectHeight, formatter: NumberFormatter())
                            .frame(width: 40)
                            .textFieldStyle(.roundedBorder)
                    }
                    .frame(width: 110, alignment: .leading)

                    Toggle("", isOn: $p.isDefaultForNewImages)
                        .labelsHidden()
                        .frame(width: 70, alignment: .center)

                    Button(role: .destructive) {
                        deletePortableCropPreset(id: p.id)
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                    .help("Delete this custom preset")
                }
            }
        }
        .frame(maxWidth: 420, alignment: .leading)
        .padding(.top, 4)
        .onChange(of: cropDraftPresets) { _, newValue in
            // Prevent infinite onChange churn while we normalize and assign back
            guard !isPersistingCropDraft else { return }
            isPersistingCropDraft = true

            cropStore.persistPresetsFromUI(newValue)

            // Store sanitizes + sorts; reflect it back into the editor.
            let cleaned = cropStore.presets
            if cleaned != cropDraftPresets {
                cropDraftPresets = cleaned
            }

            isPersistingCropDraft = false
        }
    }

    // Legacy editor (prefs-backed) only used when there is NO archive root selected.
    private var legacyCustomPresetsEditor: some View {
        Group {
            if prefs.customCropPresets.isEmpty {
                EmptyView()
            } else {
                VStack(spacing: 8) {

                    HStack {
                        Text("Crop name")
                            .font(.caption.bold())
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text("Width : Height")
                            .font(.caption.bold())
                            .frame(width: 110, alignment: .leading)

                        Text("Default")
                            .font(.caption.bold())
                            .frame(width: 70, alignment: .center)

                        Spacer().frame(width: 24)
                    }
                    .padding(.bottom, 2)

                    Divider()

                    let sortedIndices = prefs.customCropPresets.indices.sorted {
                        prefs.customCropPresets[$0].label.localizedCaseInsensitiveCompare(prefs.customCropPresets[$1].label) == .orderedAscending
                    }

                    ForEach(sortedIndices, id: \.self) { i in
                        HStack(alignment: .center, spacing: 8) {

                            TextField("Preset name", text: $prefs.customCropPresets[i].label)
                                .textFieldStyle(.roundedBorder)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            HStack(spacing: 4) {
                                TextField("W", value: $prefs.customCropPresets[i].aspectWidth, formatter: NumberFormatter())
                                    .frame(width: 40)
                                    .textFieldStyle(.roundedBorder)

                                Text(":")

                                TextField("H", value: $prefs.customCropPresets[i].aspectHeight, formatter: NumberFormatter())
                                    .frame(width: 40)
                                    .textFieldStyle(.roundedBorder)
                            }
                            .frame(width: 110, alignment: .leading)

                            Toggle("", isOn: $prefs.customCropPresets[i].isDefaultForNewImages)
                                .labelsHidden()
                                .frame(width: 70, alignment: .center)

                            Button(role: .destructive) {
                                deleteCustomPreset(prefs.customCropPresets[i])
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                            .help("Delete this custom preset")
                        }
                    }
                }
                .frame(maxWidth: 420, alignment: .leading)
                .padding(.top, 4)
            }
        }
    }

    // ============================================================
    // MARK: - [CROPS] Portable add/delete helpers
    // ============================================================

    private func addBlankPortableCropPreset() {
        let p = DMPPCropStore.Preset(
            id: UUID().uuidString,
            label: "New preset",
            aspectWidth: 4,
            aspectHeight: 5,
            isDefaultForNewImages: false
        )

        cropDraftPresets.append(p)
        cropStore.persistPresetsFromUI(cropDraftPresets)
        cropDraftPresets = cropStore.presets
    }

    private func deletePortableCropPreset(id: String) {
        cropDraftPresets.removeAll { $0.id == id }
        cropStore.persistPresetsFromUI(cropDraftPresets)
        cropDraftPresets = cropStore.presets
    }

    
    
    // ============================================================
    // MARK: - Legacy custom preset helpers (prefs-backed)
    // ============================================================

    private func addBlankCustomPreset() {
        let newPreset = DMPPUserPreferences.CustomCropPreset(
            id: UUID(),
            label: "New preset",
            aspectWidth: 4,
            aspectHeight: 5,
            isDefaultForNewImages: false
        )
        prefs.customCropPresets.append(newPreset)
    }

    private func deleteCustomPreset(_ preset: DMPPUserPreferences.CustomCropPreset) {
        prefs.customCropPresets.removeAll { $0.id == preset.id }
    }

    // ============================================================
    // MARK: - Tags section (Tags tab)
    // ============================================================

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 10) {

            Text("Tags shown as checkboxes in the editor. Descriptions are for humans.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if tagStore.tagRecords.isEmpty {
                Text("No tags loaded yet.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach($tagStore.tagRecords) { $rec in
                        TagRowView(
                            rec: $rec,
                            onDelete: { deleteTagRecord(id: rec.id) },
                            onPersist: { persistTagRecordsAndSyncPrefs() }
                        )
                    }
                }
            }

            HStack(spacing: 10) {
                Button {
                    addNewTagRecord()
                } label: {
                    Label("Add Tag", systemImage: "plus")
                }

                Spacer()

                Button("Normalize & Save") {
                    tagStore.normalizeAndSave()
                    persistTagRecordsAndSyncPrefs()
                }
                .controlSize(.small)
                .help("Cleans up duplicates/spacing and writes tags.json")
                .padding(.top, 6)
            }

            linkedTagsFilePanel()
        }
    }

    private struct TagRowView: View {
        @Binding var rec: DMPPTagStore.TagRecord

        let onDelete: () -> Void
        let onPersist: () -> Void

        @State private var nameDraft: String = ""
        @FocusState private var nameFocused: Bool

        var body: some View {
            let isReserved = rec.isReserved

            VStack(alignment: .leading, spacing: 8) {

                HStack(spacing: 10) {
                    if isReserved {
                        Text(rec.name)
                            .font(.headline)

                        Spacer()

                        Image(systemName: "lock.fill")
                            .foregroundStyle(.secondary)
                            .help("This tag name is required and cannot be renamed or deleted.")
                    } else {
                        TextField("Tag", text: $nameDraft)
                            .textFieldStyle(.roundedBorder)
                            .font(.headline)
                            .focused($nameFocused)
                            .onSubmit { commitNameIfNeeded() }
                            .onChange(of: nameFocused) { _, isFocused in
                                if !isFocused { commitNameIfNeeded() }
                            }

                        Button(role: .destructive) {
                            onDelete()
                            onPersist()
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                        .help("Remove tag")
                    }
                }

                ZStack(alignment: .topLeading) {
                    if rec.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("Description (optional)…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.top, 8)
                            .padding(.leading, 6)
                            .allowsHitTesting(false)
                    }

                    TextEditor(text: $rec.description)
                        .font(.callout)
                        .frame(minHeight: 36, idealHeight: 36, maxHeight: 140)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
                        )
                }
            }
            .padding(10)
            .background(.quaternary.opacity(0.25))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .onAppear {
                if nameDraft.isEmpty { nameDraft = rec.name }
            }
            .onChange(of: rec.name) { _, newValue in
                if !nameFocused { nameDraft = newValue }
            }
            .onChange(of: rec.description) { _, _ in
                onPersist()
            }
            .onDisappear {
                if !isReserved { commitNameIfNeeded() }
            }
        }

        private func commitNameIfNeeded() {
            let trimmed = nameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }

            if rec.name != trimmed {
                rec.name = trimmed
                onPersist()
            } else if nameDraft != trimmed {
                nameDraft = trimmed
            }
        }
    }

    private func addNewTagRecord() {
        let base = "New Tag"
        var candidate = base
        var n = 2

        let existing = Set(tagStore.tagRecords.map { $0.name.lowercased() })
        while existing.contains(candidate.lowercased()) {
            candidate = "\(base) \(n)"
            n += 1
        }

        tagStore.tagRecords.append(
            DMPPTagStore.TagRecord(
                id: UUID().uuidString,
                name: candidate,
                description: "",
                isReserved: false
            )
        )

        persistTagRecordsAndSyncPrefs()
    }

    private func deleteTagRecord(id: String) {
        tagStore.tagRecords.removeAll { $0.id == id }
        persistTagRecordsAndSyncPrefs()
    }

    private func persistTagRecordsAndSyncPrefs() {
        tagStore.persistRecordsFromUI(tagStore.tagRecords)

        let portableNames = tagStore.tags
        if prefs.availableTags != portableNames {
            prefs.availableTags = portableNames
        }
    }

    @discardableResult
    private func ensureReservedTagsExist() -> Bool {
        let reserved = ["Do Not Display", "Flagged"]
        var changed = false

        for r in reserved {
            if !prefs.availableTags.contains(r) {
                prefs.availableTags.insert(r, at: 0)
                changed = true
            }
        }

        if prefs.availableTags.isEmpty {
            prefs.availableTags = ["Do Not Display", "Flagged"]
            changed = true
        }

        return changed
    }

    // ============================================================
    // MARK: - Locations section (Tab)
    // ============================================================

    private var locationsSection: some View {
        VStack(alignment: .leading, spacing: 10) {

            HStack(alignment: .top, spacing: 12) {

                // LEFT — List + centered Add button (alphabetical)
                VStack(spacing: 8) {

                    let sortedIDs: [UUID] = prefs.userLocations
                        .sorted {
                            $0.shortName
                                .trimmingCharacters(in: .whitespacesAndNewlines)
                                .localizedCaseInsensitiveCompare(
                                    $1.shortName.trimmingCharacters(in: .whitespacesAndNewlines)
                                ) == .orderedAscending
                        }
                        .map(\.id)

                    List(selection: $selectedLocationID) {
                        ForEach(sortedIDs, id: \.self) { id in
                            if let loc = prefs.userLocations.first(where: { $0.id == id }) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(loc.shortName.isEmpty ? "Untitled" : loc.shortName)
                                        .font(.headline)

                                    Text(locationSubtitle(loc))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                .padding(.vertical, 2)
                                .tag(loc.id)
                            }
                        }
                    }
                    .frame(minWidth: 220, idealWidth: 240)
                    .onAppear {
                        if selectedLocationID == nil, let firstID = sortedIDs.first {
                            selectedLocationID = firstID
                        }
                    }
                    .onChange(of: prefs.userLocations) { _, newList in
                        guard let sel = selectedLocationID else {
                            if let firstID = newList
                                .sorted(by: {
                                    $0.shortName.trimmingCharacters(in: .whitespacesAndNewlines)
                                        .localizedCaseInsensitiveCompare(
                                            $1.shortName.trimmingCharacters(in: .whitespacesAndNewlines)
                                        ) == .orderedAscending
                                })
                                .first?.id {
                                selectedLocationID = firstID
                            }
                            return
                        }

                        if !newList.contains(where: { $0.id == sel }) {
                            selectedLocationID = newList
                                .sorted(by: {
                                    $0.shortName.trimmingCharacters(in: .whitespacesAndNewlines)
                                        .localizedCaseInsensitiveCompare(
                                            $1.shortName.trimmingCharacters(in: .whitespacesAndNewlines)
                                        ) == .orderedAscending
                                })
                                .first?.id
                        }
                    }

                    HStack {
                        Spacer()
                        Button {
                            addBlankUserLocationAndSelect()
                        } label: {
                            Label("Add Location", systemImage: "plus")
                        }
                        .buttonStyle(.borderedProminent)
                        Spacer()
                    }
                    .padding(.bottom, 4)
                }

                // RIGHT — Detail editor + delete (selected only)
                GroupBox {
                    if let idx = selectedLocationIndex() {
                        let locBinding = $prefs.userLocations[idx]

                        VStack(alignment: .leading, spacing: 12) {

                            HStack(alignment: .top, spacing: 10) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Short Name")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    TextField("", text: locBinding.shortName)
                                        .focused($focusedField, equals: .locationShortName(locBinding.wrappedValue.id))
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 220)
                                }

                                Spacer()

                                Button(role: .destructive) {
                                    deleteSelectedLocation()
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                .buttonStyle(.bordered)
                                .help("Delete this saved location")
                            }

                            Divider().padding(.vertical, 2)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Description")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                TextField("", text: nonOptional(locBinding.description))
                                    .textFieldStyle(.roundedBorder)
                            }

                            VStack(alignment: .leading, spacing: 10) {

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Street Address")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    TextField("", text: nonOptional(locBinding.streetAddress))
                                        .textFieldStyle(.roundedBorder)
                                }

                                HStack(spacing: 10) {

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("City")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        TextField("", text: nonOptional(locBinding.city))
                                            .textFieldStyle(.roundedBorder)
                                            .frame(width: 130)
                                    }

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("State")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        TextField("", text: nonOptional(locBinding.state))
                                            .textFieldStyle(.roundedBorder)
                                            .frame(width: 70)
                                    }

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Country")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        TextField("", text: nonOptional(locBinding.country))
                                            .textFieldStyle(.roundedBorder)
                                            .frame(width: 140)
                                    }
                                }
                            }

                            // Linked file (advanced)
                            GroupBox {
                                DisclosureGroup("Linked file (advanced)") {
                                    VStack(alignment: .leading, spacing: 10) {
                                        if let url = locationStore.locationsFileURL() {

                                            HStack(spacing: 10) {
                                                Image(systemName: "touchid")
                                                    .foregroundStyle(.secondary)

                                                Text(url.lastPathComponent)
                                                    .font(.caption.weight(.semibold))
                                                    .padding(.horizontal, 10)
                                                    .padding(.vertical, 6)
                                                    .background(.quaternary.opacity(0.6))
                                                    .clipShape(Capsule())

                                                Spacer()
                                            }

                                            fingerprintChip(label: "Fingerprint", value: fingerprint(for: url))

                                            Text(url.path)
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                                .textSelection(.enabled)
                                                .lineLimit(2)

                                            HStack(spacing: 10) {
                                                Button("Copy file name") { copyToClipboard(url.lastPathComponent) }
                                                Button("Copy full path") { copyToClipboard(url.path) }
                                                Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
                                            }
                                            .controlSize(.small)

                                        } else {
                                            Text("Picture Library Folder isn’t configured yet, so the linked file can’t be shown.")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .padding(.top, 8)
                                }
                                .padding(8)
                            }

                            Spacer(minLength: 0)
                        }
                        .padding(10)

                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("No location selected")
                                .font(.headline)
                            Text("Select a location on the left, or click “Add Location”.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(12)
                    }
                }
            }
        }
    }

    private func selectedLocationIndex() -> Int? {
        guard let id = selectedLocationID else { return nil }
        return prefs.userLocations.firstIndex(where: { $0.id == id })
    }

    private func addBlankUserLocationAndSelect() {
        let newLoc = DMPPUserLocation(
            id: UUID(),
            shortName: "New location",
            description: nil,
            streetAddress: nil,
            city: nil,
            state: nil,
            country: defaultCountryName()
        )
        prefs.userLocations.append(newLoc)
        selectedLocationID = newLoc.id

        DispatchQueue.main.async {
            focusedField = .locationShortName(newLoc.id)
        }
    }

    private func locationSubtitle(_ loc: DMPPUserLocation) -> String {
        let desc = (loc.description ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !desc.isEmpty { return desc }

        let city = (loc.city ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let state = (loc.state ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let country = (loc.country ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        if !city.isEmpty && !state.isEmpty { return "\(city), \(state)" }
        if !city.isEmpty { return city }
        if !state.isEmpty { return state }
        if !country.isEmpty { return country }

        return "—"
    }

    private func defaultCountryName() -> String? {
        if let code = Locale.current.region?.identifier, !code.isEmpty {
            return Locale.current.localizedString(forRegionCode: code) ?? code
        }
        return nil
    }

    private func deleteSelectedLocation() {
        guard let idx = selectedLocationIndex() else { return }

        let deletedID = prefs.userLocations[idx].id
        prefs.userLocations.remove(at: idx)

        if prefs.userLocations.isEmpty {
            selectedLocationID = nil
            return
        }

        let newIndex = min(idx, prefs.userLocations.count - 1)
        selectedLocationID = prefs.userLocations[newIndex].id

        if selectedLocationID == deletedID {
            selectedLocationID = prefs.userLocations.first?.id
        }
    }

    private func nonOptional(_ binding: Binding<String?>) -> Binding<String> {
        Binding<String>(
            get: { binding.wrappedValue ?? "" },
            set: { newValue in
                let t = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                binding.wrappedValue = t.isEmpty ? nil : t
            }
        )
    }
}

