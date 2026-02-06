import SwiftUI
import AppKit
import CryptoKit

// cp-2025-12-29-02(SETTINGS-TABS-HOSTFIX)



struct DMPPCropPreferencesView: View {

    /// User-level preferences (loaded from UserDefaults).
    @State private var prefs: DMPPUserPreferences = .load()
    @State private var selectedLocationID: UUID? = nil
    @FocusState private var focusedField: FocusField?
    
    @EnvironmentObject var archiveStore: DMPPArchiveStore
 

    @StateObject private var tagStore = DMPPTagStore()
    @StateObject private var locationStore = DMPPLocationStore()
    
    @State private var showLinkedFileDetails: Bool = false
    @State private var showLinkedTagsFileDetails: Bool = false


    private enum FocusField: Hashable {
        case locationShortName(UUID)
    }



    var body: some View {
        TabView {

            // =====================================================
            // CROPS TAB
            // =====================================================
            VStack(alignment: .leading, spacing: 16) {

                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("Crop Presets")
                        .font(.title2.bold())
                    Text("Manage crops. Checked crops are created for pictures by default; all crops are available to add at any time.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 4)

                Divider()

                // Main content
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {

                        // Built-in default presets
                        builtInPresetsSection

                        Divider()

                        // Custom presets
                        customPresetsSection
                    }
                    .padding(.vertical, 4)
                }

                Spacer(minLength: 0)
            }
            .padding()
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: .topLeading
            )
            .tabItem {
                Label("Crops", systemImage: "crop")
            }

            // =====================================================
            // LOCATIONS TAB
            // =====================================================
            VStack(alignment: .leading, spacing: 16) {

                // Header
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
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: .topLeading
            )
            .tabItem {
                Label("Locations", systemImage: "mappin.and.ellipse")
            }

            // =====================================================
            // PEOPLE TAB
            // =====================================================
            VStack(alignment: .leading, spacing: 16) {
                // Header
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
            .tabItem {
                Label("People", systemImage: "person.2")
            }

            // =====================================================
            // TAGS TAB
            // =====================================================
            VStack(alignment: .leading, spacing: 16) {

                // Header
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
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: .topLeading
            )
            .tabItem {
                Label("Tags", systemImage: "tag")
            }

            // =====================================================
            // GENERAL TAB (Fingerprint + Copy chips)
            // =====================================================
            VStack(alignment: .leading, spacing: 16) {

                // Header
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
                            // Friendly summary first
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

                            // Advanced: hidden by default
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
                                // The “control” the user clicks
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
                    .padding(8)

                    .padding(10)
                }

                Spacer(minLength: 0)
            }
            .padding()
            .frame(maxWidth: .infinity,
                   maxHeight: .infinity,
                   alignment: .topLeading)
            .tabItem {
                Label("General", systemImage: "gearshape")
            }

            .padding()
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: .topLeading
            )
            .tabItem {
                Label("General", systemImage: "gearshape")
            }
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
        // [PREFS-SAVE] Save + broadcast when crop defaults change
        .onChange(of: prefs.defaultCropPresets) { _, _ in
            prefs.save()
        }
        // [PREFS-SAVE] Save + broadcast when custom presets change (add/remove/rename/values)
        .onChange(of: prefs.customCropPresets) { _, _ in
            prefs.save()
        }

        .onAppear {
            // -------------------------------
            // TAGS
            // -------------------------------
            tagStore.configureForArchiveRoot(
                archiveStore.archiveRootURL,
                fallbackTags: prefs.availableTags
            )
            tagStore.migrateFromLegacyPrefsIfNeeded(legacyTags: prefs.availableTags)

            syncTagsFromPortableIntoPrefs()

            // -------------------------------
            // LOCATIONS
            // -------------------------------
            locationStore.configureForArchiveRoot(
                archiveStore.archiveRootURL,
                fallbackLocations: prefs.userLocations
            )
            syncLocationsFromPortableIntoPrefs()
        }
        .onChange(of: archiveStore.archiveRootURL) { _, newRoot in
            // -------------------------------
            // TAGS
            // -------------------------------
            tagStore.configureForArchiveRoot(
                newRoot,
                fallbackTags: prefs.availableTags
            )
            tagStore.migrateFromLegacyPrefsIfNeeded(legacyTags: prefs.availableTags)

            syncTagsFromPortableIntoPrefs()

            // -------------------------------
            // LOCATIONS
            // -------------------------------
            locationStore.configureForArchiveRoot(
                newRoot,
                fallbackLocations: prefs.userLocations
            )
            syncLocationsFromPortableIntoPrefs()
        }
        .onChange(of: prefs.availableTags) { _, _ in
            // Every add/edit/delete writes to tags.json (only works when a root is configured)
            persistPrefsTagsToPortable()
        }
        .onChange(of: prefs.userLocations) { _, _ in
            // Every add/edit/delete writes to locations.json (only works when a root is configured)
            persistPrefsLocationsToPortable()
        }

    }
    // MARK: - General tab helpers

    private func copyToClipboard(_ s: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(s, forType: .string)
    }

    private func fingerprint(for url: URL) -> String {
        // Stable across launches/machines for the same path string.
        // Short enough to read; long enough to be useful.
        let input = Data(url.path.utf8)
        let digest = SHA256.hash(data: input)
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        // 12 chars is a nice “chip” size
        return String(hex.prefix(12)).uppercased()
    }
    
    private func syncTagsFromPortableIntoPrefs() {
        // 1) Ensure TagStore is pointed at the current root and seed if needed.
        tagStore.configureForArchiveRoot(
            archiveStore.archiveRootURL,
            fallbackTags: prefs.availableTags
        )

        // 2) Pull portable truth into prefs (canonical + includes reserved tags)
        let portable = tagStore.tags
        guard !portable.isEmpty else { return }

        // Avoid infinite churn: only assign if it actually changed
        if prefs.availableTags != portable {
            prefs.availableTags = portable
        }
    }

    private func persistPrefsTagsToPortable() {
        // Persist whatever the UI currently has; store will sanitize + enforce reserved tags.
        tagStore.persistTagsFromUI(prefs.availableTags)

        // Optional: keep prefs in sync with sanitized portable truth (prevents “flagged ” etc.)
        let portable = tagStore.tags
        if !portable.isEmpty, prefs.availableTags != portable {
            prefs.availableTags = portable
        }
    }

    private func syncLocationsFromPortableIntoPrefs() {
        // 1) Ensure store is pointed at current root and seeded if needed.
        locationStore.configureForArchiveRoot(
            archiveStore.archiveRootURL,
            fallbackLocations: prefs.userLocations
        )

        // 2) Pull portable truth into prefs (canonical)
        let portable = locationStore.locations
        guard !portable.isEmpty else { return }

        // Avoid churn
        if prefs.userLocations != portable {
            prefs.userLocations = portable
        }
    }

    private func persistPrefsLocationsToPortable() {
        locationStore.persistLocationsFromUI(prefs.userLocations)

        // Optional: sync back sanitized portable truth
        let portable = locationStore.locations
        if !portable.isEmpty, prefs.userLocations != portable {
            prefs.userLocations = portable
        }
    }

    
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

                        // “Fingerprint chip” style: icon + filename capsule
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

    
    // MARK: - Sections (Crops tab)

    // [CROPS-UI] Built-in preset rows used by Settings (sorted for display)
    private struct BuiltInPresetRow: Identifiable {
        let id: DMPPUserPreferences.CropPresetID
        let title: String
        let education: String
    }

    private var builtInPresetRowsSorted: [BuiltInPresetRow] {
        let rows: [BuiltInPresetRow] = [
            .init(id: .headshot8x10,   title: "Headshot 8×10",       education: "Portrait 4:5 with headshot guides"),
            .init(id: .original,       title: "Original (full image)", education: "Full frame, aspect from actual pixels."),

            .init(id: .landscape14x11, title: "Landscape 14:11",     education: "Includes print sizes 11×14…"),
            .init(id: .landscape16x9,  title: "Landscape 16:9",      education: "Typical TV / display aspect."),
            .init(id: .landscape3x2,   title: "Landscape 3:2",       education: "Includes print sizes 4×6, 8×12…"),
            .init(id: .landscape4x3,   title: "Landscape 4:3",       education: "Includes print sizes 18×24…"),
            .init(id: .landscape5x4,   title: "Landscape 5:4",       education: "Includes print sizes 4×5, 8×10…"),
            .init(id: .landscape7x5,   title: "Landscape 7:5",       education: "Includes print sizes 5×7…"),

            .init(id: .portrait11x14,  title: "Portrait 11:14",      education: "Includes print sizes 11×14…"),
            .init(id: .portrait2x3,    title: "Portrait 2:3",        education: "Includes print sizes 4×6, 8×12…"),
            .init(id: .portrait3x4,    title: "Portrait 3:4",        education: "Includes print sizes 18×24…"),
            .init(id: .portrait4x5,    title: "Portrait 4:5",        education: "Includes print sizes 4×5, 8×10…"),
            .init(id: .portrait5x7,    title: "Portrait 5:7",        education: "Includes print sizes 5×7…"),
            .init(id: .portrait9x16,   title: "Portrait 9:16",       education: "Vertical screen"),

            .init(id: .square1x1,      title: "Square 1:1",          education: "Square crops (social, grids, etc.)"),
        ]

        // Alphabetical by title, matching your dropdown intent
        return rows.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    
    /// Section for the known built-in presets (Original, 16:9, 8×10, etc.).
    private var builtInPresetsSection: some View {
        VStack(alignment: .leading, spacing: 8) {

            Text("Standard crops")
                .font(.headline)

        //    Text("These crops are automatically created when an image has no existing sidecar.")
          //      .font(.footnote)
          //      .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 6) {

                // Header row so “Default” is a right-side column like Custom
                HStack {
                    Spacer()
                    Text("Default")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .frame(width: 70, alignment: .center)
                }
                .padding(.bottom, 2)

                ForEach(builtInPresetRowsSorted) { row in
                    builtInRow(
                        id: row.id,
                        title: row.title,
                        subtitle: row.education
                    )
                }
            }
           
           .frame(maxWidth: 450, alignment: .leading)
            .padding(.top, 4)

        }
    }
   

    /// A single row for a built-in preset toggle.
    // [CROPS-UI] Preset row with right-side Default checkbox and inline education
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
            // Single line: “Landscape 5:4 — Includes print sizes 4×5, 8×10…”
            Text("\(title) — \(subtitle)")
                .frame(maxWidth: .infinity, alignment: .leading)

            Toggle("", isOn: isOnBinding)
                .labelsHidden()
                .toggleStyle(.checkbox)
                .frame(width: 70, alignment: .center)
        }
        .padding(.vertical, 2)
    }


    /// Section for user-defined custom presets.
    private var customPresetsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Custom crops")
                .font(.headline)

         //   Text("Define your own named aspect ratios and choose which ones should be created for new images.")
          //      .font(.footnote)
          //      .foregroundStyle(.secondary)

            if prefs.customCropPresets.isEmpty {
                Text("No custom presets yet. Click “Add Crop” to create one.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            } else {
                VStack(spacing: 8) {
                    // Column headers
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

                        Spacer().frame(width: 24) // for delete icon
                    }
                    .padding(.bottom, 2)

                    Divider()

                    // Editable rows
                    let sortedIndices = prefs.customCropPresets.indices.sorted {
                        prefs.customCropPresets[$0].label.localizedCaseInsensitiveCompare(prefs.customCropPresets[$1].label) == .orderedAscending
                    }

                    ForEach(sortedIndices, id: \.self) { i in
                        HStack(alignment: .center, spacing: 8) {

                            // Label
                            TextField("Preset name", text: $prefs.customCropPresets[i].label)
                                .textFieldStyle(.roundedBorder)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            // Aspect W:H
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

                            // Default checkbox
                            Toggle("", isOn: $prefs.customCropPresets[i].isDefaultForNewImages)
                                .labelsHidden()
                                .frame(width: 70, alignment: .center)

                            // Delete button
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

            Button {
                addBlankCustomPreset()
            } label: {
                Label("Add Crop", systemImage: "plus")
            }
            .padding(.top, 6)
        }
    }

    // MARK: - Tags section (Tags tab)

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
                            onDelete: {
                                deleteTagRecord(id: rec.id)
                            },
                            onPersist: {
                                persistTagRecordsAndSyncPrefs()
                            }
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
        @State private var descExpanded: Bool = false
        private let descCollapsedHeight: CGFloat = 80
        private let descExpandedHeight: CGFloat = 180


        let onDelete: () -> Void
        let onPersist: () -> Void

        // Local draft so typing spaces doesn't get nuked by sanitize-on-save
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
                                // When the field loses focus, commit once
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

                // Multiline description (editable even for reserved tags)
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
                // Initialize draft from record when row appears
                if nameDraft.isEmpty {
                    nameDraft = rec.name
                }
            }
            .onChange(of: rec.name) { _, newValue in
                // If record name changes externally, reflect it—unless user is actively typing
                if !nameFocused {
                    nameDraft = newValue
                }
            }
            // Keep description persisting live (your description trailing-space issue is already fixed)
            .onChange(of: rec.description) { _, _ in
                onPersist()
            }
            .onDisappear {
                // Defensive: commit before row goes away
                if !isReserved {
                    commitNameIfNeeded()
                }
            }
        }

        private func commitNameIfNeeded() {
            let trimmed = nameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }

            // Only write/persist if it actually changed
            if rec.name != trimmed {
                rec.name = trimmed
                onPersist()
            } else if nameDraft != trimmed {
                // User typed trailing spaces; normalize the field display without rewriting the store
                nameDraft = trimmed
            }
        }
    }


    // Existing helpers (keep yours as-is)

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

    /// Writes records to tags.json (sanitizes/keeps reserved), then syncs prefs.availableTags to names.
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
            prefs.availableTags = [
                "Do Not Display",
                "Flagged"
            ]
            changed = true
        }

        return changed
    }


    // MARK: - Locations section (Tab)

    private var locationsSection: some View {
        VStack(alignment: .leading, spacing: 10) {

            HStack(alignment: .top, spacing: 12) {

                // =====================================================
                // LEFT — List + centered Add button (alphabetical)
                // =====================================================
                VStack(spacing: 8) {

                    // Sort for display, but keep edits operating on prefs.userLocations
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
                        // Keep selection stable / pick first when empty
                        if selectedLocationID == nil,
                           let firstID = sortedIDs.first {
                            selectedLocationID = firstID
                        }
                    }
                    .onChange(of: prefs.userLocations) { _, newList in
                        // If selection was deleted, choose a sensible fallback (alphabetical first)
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

                // =====================================================
                // RIGHT — Detail editor + delete (selected only)
                // =====================================================
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

                            // =====================================================
                            // Linked file (advanced)
                            // =====================================================
                            GroupBox {
                                DisclosureGroup("Linked file (advanced)") {
                                    VStack(alignment: .leading, spacing: 10) {
                                        if let url = locationStore.locationsFileURL() {

                                            // “Fingerprint chip” style: icon + filename capsule
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
                                                Button("Copy file name") {
                                                    copyToClipboard(url.lastPathComponent)
                                                }
                                                Button("Copy full path") {
                                                    copyToClipboard(url.path)
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




    // MARK: - Helpers

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

    private func locationBinding(for id: UUID) -> Binding<DMPPUserLocation>? {
        guard let idx = prefs.userLocations.firstIndex(where: { $0.id == id }) else { return nil }
        return $prefs.userLocations[idx]
    }



    private func deleteLocation(id: UUID) {
        guard let idx = prefs.userLocations.firstIndex(where: { $0.id == id }) else { return }

        prefs.userLocations.remove(at: idx)

        // Choose a new selection (same index if possible, otherwise previous, otherwise nil)
        if prefs.userLocations.isEmpty {
            selectedLocationID = nil
        } else {
            let nextIndex = min(idx, prefs.userLocations.count - 1)
            selectedLocationID = prefs.userLocations[nextIndex].id
        }
    }

    private struct LocationDetailEditor: View {
        @Binding var loc: DMPPUserLocation

        var onDelete: () -> Void
        var nonOptional: (Binding<String?>) -> Binding<String>

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {

                // Top row: short + description + delete
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Short Name")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("", text: $loc.shortName)
                            .textFieldStyle(.roundedBorder)
                    }
                    .frame(maxWidth: 280)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Description")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("", text: nonOptional($loc.description))
                            .textFieldStyle(.roundedBorder)
                    }

                    Spacer()

                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                }

                Divider()

                // Address fields
                VStack(alignment: .leading, spacing: 10) {

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Street Address")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("", text: nonOptional($loc.streetAddress))
                            .textFieldStyle(.roundedBorder)
                    }

                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("City")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            TextField("", text: nonOptional($loc.city))
                                .textFieldStyle(.roundedBorder)
                        }
                        .frame(width: 160)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("State")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            TextField("", text: nonOptional($loc.state))
                                .textFieldStyle(.roundedBorder)
                        }
                        .frame(width: 80)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Country")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            TextField("", text: nonOptional($loc.country))
                                .textFieldStyle(.roundedBorder)
                        }
                        .frame(width: 160)

                        Spacer()
                    }
                }

                Spacer()
            }
            .padding(12)
            .background(.quaternary.opacity(0.25))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
            country: defaultCountryName(),   // <- default here
            
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

        // Prefer "City, ST" then fall back to "Country" then "—"
        if !city.isEmpty && !state.isEmpty { return "\(city), \(state)" }
        if !city.isEmpty { return city }
        if !state.isEmpty { return state }
        if !country.isEmpty { return country }

        return "—"
    }

    private func defaultCountryName() -> String? {
        // macOS Region setting (not GPS)
        if let code = Locale.current.region?.identifier, !code.isEmpty {
            // Convert "US" -> "United States" (localized)
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

        // Pick next item if possible; otherwise previous; otherwise first
        let newIndex = min(idx, prefs.userLocations.count - 1)
        selectedLocationID = prefs.userLocations[newIndex].id

        // sanity: if somehow still pointing at deleted
        if selectedLocationID == deletedID {
            selectedLocationID = prefs.userLocations.first?.id
        }
    }

    
    private func addBlankUserLocation() {
        let newLoc = DMPPUserLocation(
            id: UUID(),
            shortName: "New location",
            description: nil,
            streetAddress: nil,
            city: nil,
            state: nil,
            country: nil
        )
        prefs.userLocations.append(newLoc)
    }

    private func deleteUserLocation(_ loc: DMPPUserLocation) {
        prefs.userLocations.removeAll { $0.id == loc.id }
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
