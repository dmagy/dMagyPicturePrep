import SwiftUI
import AppKit
import Observation



// dMPP-2025-11-21-NAV2+UI — Folder navigation + crops + dMPMS sidecar read/write

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
            // [DMPP-SI-TOOLBAR] Top toolbar: folder + full path
            // -----------------------------------------------------
            HStack(spacing: 12) {

                if let folderURL {
                    // [DMPP-TB-FOLDER-SELECTED] Big folder button with folder name
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
                } else {
                    // [DMPP-TB-FOLDER-NONE] Initial “Choose Folder…” button
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

                // [DMPP-TB-FULL-PATH] Right-justified full path (if we have a folder)
                if let folderURL {
                    Text(folderURL.path)
                        .font(.caption)
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

                // Main split view: crops/preview on left, metadata on right
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

                // -----------------------------------------------------
                // [DMPP-SI-BOTTOM-NAV] Delete tab + info line + Save & navigation
                // -----------------------------------------------------
                HStack(spacing: 8) {

                    // Delete Crop button in a red pill inside a white rounded box,
                    // visually hooked into the content above with a slight negative top padding.
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
                                        .fill(Color.red)              // red inner pill
                                )
                        }
                        .buttonStyle(.plain)
                        .padding(10)                                   // padding inside the white box
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.white)                    // white outer tab box
                        )
                        .padding(.top, -16)                            // pull it upward into the bar
                        .padding(.leading, 16)
                    }

                    // Spacer between Delete tab and the info text
                    Spacer(minLength: 8)

                    // Info text, centered between Delete and Save/navigation
                    Text("Edits are saved separately; your original photo is never changed.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity)

                    // Spacer between text and the Save/navigation cluster
                    Spacer(minLength: 8)

                    // Save + navigation buttons on the right
                    Button("Save") {
                        saveCurrentMetadata()
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut("s", modifiers: [.command])
                    .help("Save notes and crop for this picture (original photo is never changed).")

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
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(.thinMaterial)

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

    @Environment(\.openSettings) private var openSettings


    /// For the crop editor we only need read access to the view model.
    /// This is a plain value, not @Bindable.
    var vm: DMPPImageEditorViewModel

    /// Convenience accessor: current saved custom presets.
    /// Reloads from UserDefaults each time the menu is shown.
    private var customPresets: [DMPPUserPreferences.CustomCropPreset] {
        DMPPUserPreferences.load().customCropPresets
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // -------------------------------------------------
            // [DMPP-SI-CROP-ROW] Segmented crops + New Crop menu on one row
            // -------------------------------------------------
            HStack(alignment: .center, spacing: 12) {

                // Segmented control for existing crops (left)
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

                // New Crop menu (right)
                Menu("New Crop") {

                    // -------------------------------------------------
                    // Screen
                    // -------------------------------------------------
                    Menu("Screen") {
                        Button("Original (full image)") {
                            vm.addPresetOriginalCrop()
                        }
                        .disabled(vm.hasPresetOriginal)

                        Button("Landscape 16:9") {
                            vm.addPresetLandscape16x9()
                        }
                        .disabled(vm.hasPresetLandscape16x9)

                        Button("Portrait 9:16") {
                            vm.addPresetPortrait9x16()
                        }
                        .disabled(vm.hasPresetPortrait9x16)

                        Button("Landscape 4:3") {
                            vm.addPresetLandscape4x3()
                        }
                        .disabled(vm.hasPresetLandscape4x3)
                    }

                    // -------------------------------------------------
                    // Print & Frames
                    // -------------------------------------------------
                    Menu("Print & Frames") {
                        Button("Portrait 8×10") {
                            vm.addPresetPortrait8x10()
                        }
                        .disabled(vm.hasPresetPortrait8x10)

                        Button("Headshot 8×10") {
                            vm.addPresetHeadshot8x10()
                        }
                        .disabled(vm.hasPresetHeadshot8x10)

                        Button("Landscape 4×6") {
                            vm.addPresetLandscape4x6()
                        }
                        .disabled(vm.hasPresetLandscape4x6)
                    }

                    // -------------------------------------------------
                    // Creative & Custom
                    // -------------------------------------------------
                    Menu("Creative & Custom") {
                        Button("Square 1:1") {
                            vm.addPresetSquare1x1()
                        }
                        .disabled(vm.hasPresetSquare1x1)

                        Button("Freeform") {
                            vm.addFreeformCrop()
                        }

                        // Custom presets from Settings
                        if !customPresets.isEmpty {
                            Divider()

                            ForEach(customPresets) { preset in
                                // Don’t allow duplicate label+aspect for this image
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

                // [DMPP-SI-CROP-CONTROLS] Crop column: title, +, slider, -
                if vm.selectedCrop != nil {
                    GeometryReader { sliderGeo in
                        VStack(spacing: 8) {
                            Text("Crop")
                                .font(.caption)

                            // Zoom in → smaller crop (more zoom)
                            Button {
                                vm.scaleSelectedCrop(by: 0.9)
                            } label: {
                                Image(systemName: "plus")
                            }
                            .buttonStyle(.borderedProminent)
                            .help("Zoom in (smaller crop)")

                            Spacer(minLength: 8)

                            // Tall vertical slider whose *length* matches column height
                            GeometryReader { innerGeo in
                                Slider(
                                    value: Binding(
                                        get: { vm.selectedCropSizeSliderValue },
                                        set: { vm.selectedCropSizeSliderValue = $0 }
                                    ),
                                    in: 0...1
                                )
                                // The width BEFORE rotation becomes the vertical length after -90°
                                .frame(width: max(innerGeo.size.height - 40, 120))
                                .rotationEffect(.degrees(-90))
                                // Center the rotated slider inside the column
                                .position(
                                    x: innerGeo.size.width / 2,
                                    y: innerGeo.size.height / 2
                                )
                            }
                            .frame(maxHeight: .infinity)

                            Spacer(minLength: 8)

                            // Zoom out → larger crop (less zoom)
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

            // [DMPP-SI-ASPECT-LABEL] (hidden for now)
            // We used to show the computed aspect ratio here,
            // but that's more technical than most users need.
        }
    }
}





// MARK: - Right Pane (Metadata)

struct DMPPMetadataFormPane: View {

    @Bindable var vm: DMPPImageEditorViewModel
    @Environment(\.openSettings) private var openSettings
    @Environment(\.openWindow) private var openWindow
  

    // Tags from preferences, kept in sync via notification.
    @State private var availableTags: [String] = DMPPUserPreferences.load().availableTags
    
    @State private var dateWarning: String? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // FILE
                GroupBox("File") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(vm.metadata.sourceFile)
                            .font(.callout.monospaced())
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 8)
                       .padding(.vertical, 8)
                }
          
                // DESCRIPTION
                GroupBox("Description") {
                    VStack(alignment: .leading, spacing: 8) {
                        // Title
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Title")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            TextField(
                                "",
                                text: $vm.metadata.title
                            )
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: .infinity)
                        }
                        .padding(.horizontal, 8)
                           .padding(.vertical, 8)
                        // Description
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Description")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            TextField(
                                "",
                                text: $vm.metadata.description,
                                axis: .vertical
                            )
                            .lineLimit(2...6)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: .infinity)
                        }
                        .padding(.horizontal, 8)
                           .padding(.vertical, 8)
                    }
                }

                // DATE / ERA
                GroupBox("Date / Era") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Date Taken or Era")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        TextField(
                            "",
                            text: $vm.metadata.dateTaken
                        )
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: .infinity)
                        .onChange(of: vm.metadata.dateTaken) { oldValue, newValue in
                            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)

                            // Keep the machine-friendly range in sync
                            vm.metadata.dateRange = DmpmsDateRange.from(dateTaken: trimmed)

                            // Keep the warning text in sync
                            dateWarning = dateValidationMessage(for: trimmed)

                            // Recompute ages for all peopleV2 entries
                            recomputeAgesForCurrentImage()
                        }

                        if let dateWarning, !dateWarning.isEmpty {
                            Text(dateWarning)
                                .font(.caption2)
                                .foregroundStyle(.red)
                        } else {
                            Text("Partial dates, decades, and ranges are allowed.\nExamples: 1976-07-04, 1976-07, 1976, 1970s, 1975-1977")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                }




                // TAGS & PEOPLE
                // TAGS
 
                GroupBox("Tags") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tags")
                            .font(.caption)
                            .foregroundStyle(.secondary)

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
                                            get: {
                                                vm.metadata.tags.contains(tag)
                                            },
                                            set: { isOn in
                                                if isOn {
                                                    if !vm.metadata.tags.contains(tag) {
                                                        vm.metadata.tags.append(tag)
                                                    }
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

                        Button("Add / Edit tags…") {
                            openSettings()
                        }
                        .buttonStyle(.link)
                        .font(.caption)
                        .tint(.accentColor)
                        .padding(.top, 4)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                }


                // PEOPLE
                GroupBox("People") {
                    VStack(alignment: .leading, spacing: 8) {

                        // -------------------------------------------------
                        // People in this photo (summary ABOVE the checklists)
                        // -------------------------------------------------
                        VStack(alignment: .leading, spacing: 2) {
                            Text("People in this photo")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            let sortedPeople = vm.metadata.peopleV2
                                .sorted { lhs, rhs in
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
                                Text(
                                    sortedPeople
                                        .map { person in
                                            if let age = person.ageAtPhoto,
                                               !age.isEmpty {
                                                // Show "Name (age)" or "Name (5-7)" depending on stored value
                                                return "\(person.shortNameSnapshot) (\(age))"
                                            } else {
                                                // No age info → just the name
                                                return person.shortNameSnapshot
                                            }
                                        }
                                        .joined(separator: ", ")
                                )
                                .font(.caption)
                            }

                        }

                        Divider()
                            .padding(.vertical, 4)

                        // -------------------------------------------------
                        // Favorites column
                        // -------------------------------------------------
                        if !identityStore.favoriteIdentities.isEmpty {
                            Text("Favorites")
                                .font(.caption.bold())

                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(identityStore.favoriteIdentities) { identity in
                                    Toggle(identity.shortName, isOn: bindingForIdentity(identity))
                                        .toggleStyle(.checkbox)
                                }
                            }
                        }

                        // -------------------------------------------------
                        // All others column
                        // -------------------------------------------------
                        if !identityStore.nonFavoriteIdentities.isEmpty {
                            Text("All others")
                                .font(.caption.bold())
                                .padding(.top, 6)

                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(identityStore.nonFavoriteIdentities) { identity in
                                    Toggle(identity.shortName, isOn: bindingForIdentity(identity))
                                        .toggleStyle(.checkbox)
                                }
                            }
                        }
                        HStack(spacing: 8) {
                            Button("Open People Manager…") {
                                openWindow(id: "People-Manager")
                            }
                            .buttonStyle(.link)
                            .font(.caption)
                            .tint(.accentColor) // use OS theme color for the link

                          //  Text("Manage identities, favorites, and details.")
                           //     .font(.caption)
                             ///   .foregroundStyle(.secondary)

                            Spacer()
                        }
                        .padding(.top, 4)


                        // Optional helper text
                        Text("Check people who appear in this photo; they’ll be added left-to-right in the front row by default.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.top, 6)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                }


                Spacer(minLength: 0)
            }
            .padding()
        }
        .onAppear {
            reloadAvailableTags()
        }
        .onReceive(
            NotificationCenter.default.publisher(for: .dmppPreferencesChanged)
        ) { _ in
            reloadAvailableTags()
        }
    }

    // MARK: - Helpers

    private func reloadAvailableTags() {
        availableTags = DMPPUserPreferences.load().availableTags
    }
    
    // MARK: - Identity helpers (People section)

    /// Shared identity store for the editor.
    private var identityStore: DMPPIdentityStore {
        DMPPIdentityStore.shared
    }

    /// Binding that reflects whether a given identity is present in this photo.
       /// - When turned ON: adds a `DmpmsPersonInPhoto` row (and mirrors legacy `people`).
       /// - When turned OFF: removes that row (and removes the shortName from legacy `people`).
       private func bindingForIdentity(_ identity: DmpmsIdentity) -> Binding<Bool> {
           Binding<Bool>(
               get: {
                   vm.metadata.peopleV2.contains { $0.identityID == identity.id }
               },
               set: { isOn in
                   if isOn {
                       // Already present? Keep legacy list in sync, then bail.
                       if vm.metadata.peopleV2.contains(where: { $0.identityID == identity.id }) {
                           if !vm.metadata.people.contains(identity.shortName) {
                               vm.metadata.people.append(identity.shortName)
                           }
                           return
                       }

                       // Compute next position in the front row (rowIndex 0).
                       let frontRowPeople = vm.metadata.peopleV2.filter { $0.rowIndex == 0 }
                       let nextPosition = (frontRowPeople.map { $0.positionIndex }.max() ?? -1) + 1

                       // New person-in-photo row; age will be filled by recomputeAgesForCurrentImage().
                       let person = DmpmsPersonInPhoto(
                           id: UUID().uuidString,
                           identityID: identity.id,
                           isUnknown: false,
                           shortNameSnapshot: identity.shortName,
                           displayNameSnapshot: identity.fullName,
                           ageAtPhoto: nil,
                           rowIndex: 0,
                           rowName: "front",
                           positionIndex: nextPosition,
                           roleHint: nil
                       )

                       vm.metadata.peopleV2.append(person)

                       // Keep legacy `people` list in sync for v1 consumers.
                       if !vm.metadata.people.contains(identity.shortName) {
                           vm.metadata.people.append(identity.shortName)
                       }

                       // Ensure ages respect current date.
                       recomputeAgesForCurrentImage()

                   } else {
                       // Turn OFF: remove from v2 + legacy people.
                       vm.metadata.peopleV2.removeAll { $0.identityID == identity.id }
                       vm.metadata.people.removeAll { $0 == identity.shortName }

                       // Recompute ages in case anything changed.
                       recomputeAgesForCurrentImage()
                   }
               }
           )
       }

    // MARK: - People / age helpers

    /// Recomputes `ageAtPhoto` for every `peopleV2` entry based on
    /// the current `metadata.dateRange` and the identity registry.
    ///
    /// Rules (v1):
    /// - If no `dateRange` → clear all ages.
    /// - If a person is marked `isUnknown` or has no identityID → age = nil.
    /// - If identity has no `birthDate` → age = nil.
    /// - Otherwise: compute integer years using earliest date in `dateRange`.
    private func recomputeAgesForCurrentImage() {
        // If there's no usable dateRange, clear all ages and bail.
        guard let dateRange = vm.metadata.dateRange else {
            for idx in vm.metadata.peopleV2.indices {
                vm.metadata.peopleV2[idx].ageAtPhoto = nil
            }
            return
        }

        // For now, we use the *earliest* date in the range as the reference.
        let photoDateYMD = dateRange.earliest

        // Walk all people in this photo.
        for idx in vm.metadata.peopleV2.indices {
            let person = vm.metadata.peopleV2[idx]

            // Unknown placeholders never get ages.
            if person.isUnknown {
                vm.metadata.peopleV2[idx].ageAtPhoto = nil
                continue
            }

            // Need a linked identity + birthDate.
            guard let identityID = person.identityID,
                  let identity = identityStore.identity(withID: identityID),
                  let birthYMD = identity.birthDate
            else {
                vm.metadata.peopleV2[idx].ageAtPhoto = nil
                continue
            }

            // Compute rough integer age in years.
            guard let years = yearsBetween(birthYMD: birthYMD, and: photoDateYMD) else {
                vm.metadata.peopleV2[idx].ageAtPhoto = nil
                continue
            }

            // For v1: simple integer-as-string, e.g. "3", "42".
            vm.metadata.peopleV2[idx].ageAtPhoto = String(years)
        }
    }

    
}

// MARK: - Date validation helper

private func dateValidationMessage(for raw: String) -> String? {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
        return nil    // no warning for blank
    }

    // Simple patterns
    let fullDate     = #"^\d{4}-\d{2}-\d{2}$"#      // 1976-07-04
    let yearMonth    = #"^\d{4}-\d{2}$"#            // 1976-07
    let yearOnly     = #"^\d{4}$"#                  // 1976
    let decade       = #"^\d{4}s$"#                 // 1970s
    let yearRange    = #"^(\d{4})-(\d{4})$"#        // 1975-1977

    func matches(_ pattern: String) -> NSTextCheckingResult? {
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(trimmed.startIndex..<trimmed.endIndex,
                            in: trimmed)
        return regex?.firstMatch(in: trimmed, options: [], range: range)
    }

    // 1) Exact matches for the simple forms
    if matches(fullDate) != nil { return nil }
    if matches(yearMonth) != nil { return nil }
    if matches(yearOnly) != nil { return nil }
    if matches(decade) != nil { return nil }

    // 2) Year range handling
    if let match = matches(yearRange) {
        if match.numberOfRanges == 3,
           let startRange = Range(match.range(at: 1), in: trimmed),
           let endRange   = Range(match.range(at: 2), in: trimmed) {

            let startYear = Int(trimmed[startRange]) ?? 0
            let endYear   = Int(trimmed[endRange]) ?? 0

            if endYear < startYear {
                return "End year must not be earlier than start year."
            } else {
                return nil  // valid range like 1975-1977
            }
        }
    }

    // 3) Anything else → soft warning
    return "Entered value does not match standard forms \nExamples: 1976-07-04, 1976-07, 1976, 1970s, 1975-1977"
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

        // Work on a mutable copy so we can tweak before encoding.
        var metadataToSave = vm.metadata

        // Keep legacy `people` in sync with peopleV2, when present.
        metadataToSave.syncLegacyPeopleFromPeopleV2IfNeeded()

        let url = sidecarURL(for: vm.imageURL)

        print("dMPP: Attempting to save metadata for \(metadataToSave.sourceFile) to:")
        print("      \(url.path)")

        do {
            let encoder = JSONEncoder()
            // Pretty-printed, but DO NOT sort keys alphabetically.
            encoder.outputFormatting = [.prettyPrinted]

            let data = try encoder.encode(metadataToSave)
            try data.write(to: url, options: .atomic)

            print("dMPP: ✅ Saved metadata successfully.")
        } catch {
            let nsError = error as NSError
            print("dMPP: ❌ Failed to save metadata for \(metadataToSave.sourceFile)")
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
            dmpmsVersion: "1.1",
            dmpmsNotice: "Created by dMagy Picture Prep. Stores metadata and crop settings for this photo. Deleting it erases edits (not the original image).",
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
// MARK: - Small helpers for age calculation

/// Parses simple "YYYY-MM-DD" strings and returns integer years difference.
/// If parsing fails, returns nil.
///
/// We assume `DmpmsDateRange` has already normalized dates to this format.
fileprivate func yearsBetween(birthYMD: String, and photoYMD: String) -> Int? {
    func components(from ymd: String) -> (year: Int, month: Int, day: Int)? {
        let parts = ymd.split(separator: "-")
        guard parts.count == 3,
              let y = Int(parts[0]),
              let m = Int(parts[1]),
              let d = Int(parts[2]) else {
            return nil
        }
        return (y, m, d)
    }

    guard let b = components(from: birthYMD),
          let p = components(from: photoYMD) else {
        return nil
    }

    var years = p.year - b.year

    // If the photo is before the birthday in that year, subtract 1.
    if (p.month, p.day) < (b.month, b.day) {
        years -= 1
    }

    return max(years, 0)
}
