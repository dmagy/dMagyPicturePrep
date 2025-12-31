import SwiftUI

// cp-2025-12-29-02(SETTINGS-TABS-HOSTFIX)

struct DMPPCropPreferencesView: View {

    /// User-level preferences (loaded from UserDefaults).
    @State private var prefs: DMPPUserPreferences = .load()
    @State private var selectedLocationID: UUID? = nil
    @FocusState private var focusedField: FocusField?

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
                    Text("Choose which crops are created by default and define your own presets.")
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
            .frame(maxWidth: .infinity,
                   maxHeight: .infinity,
                   alignment: .topLeading)
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
            .frame(maxWidth: .infinity,
                   maxHeight: .infinity,
                   alignment: .topLeading)
            .tabItem {
                Label("Locations", systemImage: "mappin.and.ellipse")
            }
            
            // =====================================================
            // PEOPLE TAB
            // =====================================================
            
            // IMPORTANT:
            // When embedded in Settings’ TabView, use the .settingsTab host so
            // we *don’t* run a NavigationSplitView inside the TabView.
            // That’s what was causing the tab strip to “shift right” and mis-route clicks.
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
            .frame(maxWidth: .infinity,
                   maxHeight: .infinity,
                   alignment: .topLeading)
            .tabItem {
                Label("Tags", systemImage: "tag")
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

        .onChange(of: prefs) { _, newValue in
            newValue.save()
        }
    }

    // MARK: - Sections (Crops tab)

    /// Section for the known built-in presets (Original, 16:9, 8×10, etc.).
    private var builtInPresetsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Default built-in crops for new images")
                .font(.headline)

            Text("These crops will be auto-created whenever dMPP sees an image with no existing sidecar.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                builtInRow(
                    id: .original,
                    title: "Original (full image)",
                    subtitle: "Full frame, aspect from actual pixels."
                )

                builtInRow(
                    id: .landscape16x9,
                    title: "Landscape 16:9",
                    subtitle: "Typical TV / display aspect."
                )

                builtInRow(
                    id: .portrait8x10,
                    title: "Portrait 8×10 (4:5)",
                    subtitle: "Standard portrait / print size."
                )

                builtInRow(
                    id: .headshot8x10,
                    title: "Headshot 8×10",
                    subtitle: "Same as 8×10, with headshot guides."
                )

                builtInRow(
                    id: .landscape4x6,
                    title: "Landscape 4×6 (3:2)",
                    subtitle: "Classic 4×6 photo print."
                )

                builtInRow(
                    id: .square1x1,
                    title: "Square 1:1",
                    subtitle: "Square crops (social, grids, etc.)."
                )
            }
            .padding(.top, 4)
        }
    }

    /// A single row for a built-in preset toggle.
    private func builtInRow(
        id: DMPPUserPreferences.CropPresetID,
        title: String,
        subtitle: String
    ) -> some View {
        let isOnBinding = Binding<Bool>(
            get: {
                prefs.defaultCropPresets.contains(id)
            },
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

        return Toggle(isOn: isOnBinding) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// Section for user-defined custom presets.
    private var customPresetsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Custom crop presets")
                .font(.headline)

            Text("Define your own named aspect ratios and choose which ones should be created for new images.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            if prefs.customCropPresets.isEmpty {
                Text("No custom presets yet. Click “Add Preset” to create one.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            } else {
                VStack(spacing: 8) {
                    // Column headers
                    HStack {
                        Text("Label")
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
                    ForEach($prefs.customCropPresets) { $preset in
                        HStack(alignment: .center, spacing: 8) {

                            // Label
                            TextField("Preset name", text: $preset.label)
                                .textFieldStyle(.roundedBorder)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            // Aspect W:H
                            HStack(spacing: 4) {
                                TextField("W", value: $preset.aspectWidth, formatter: NumberFormatter())
                                    .frame(width: 40)
                                    .textFieldStyle(.roundedBorder)
                                Text(":")
                                TextField("H", value: $preset.aspectHeight, formatter: NumberFormatter())
                                    .frame(width: 40)
                                    .textFieldStyle(.roundedBorder)
                            }
                            .frame(width: 110, alignment: .leading)

                            // Default checkbox
                            Toggle("", isOn: $preset.isDefaultForNewImages)
                                .labelsHidden()
                                .frame(width: 70, alignment: .center)

                            // Delete button
                            Button(role: .destructive) {
                                deleteCustomPreset(preset)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                            .help("Delete this custom preset")
                        }
                    }
                }
                .padding(.top, 4)
            }

            Button {
                addBlankCustomPreset()
            } label: {
                Label("Add Preset", systemImage: "plus")
            }
            .padding(.top, 6)
        }
    }

    // MARK: - Tags section (Tab)

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tags shown as checkboxes in the editor.")
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(Array(prefs.availableTags.enumerated()), id: \.offset) { index, tag in
                if tag == DMPPUserPreferences.mandatoryTagName {
                    HStack {
                        Text(tag)
                            .padding(.leading, 6)

                        Spacer()

                        Image(systemName: "lock.fill")
                            .foregroundStyle(.secondary)
                            .help("This tag is required and cannot be deleted.")
                    }
                } else {
                    HStack {
                        TextField(
                            "Tag",
                            text: Binding(
                                get: { prefs.availableTags[index] },
                                set: { prefs.availableTags[index] = $0 }
                            )
                        )

                        Spacer()

                        Button(role: .destructive) {
                            prefs.availableTags.remove(at: index)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .help("Remove tag")
                        .buttonStyle(.borderless)
                    }
                }
            }

            Button {
                prefs.availableTags.append("New Tag")
            } label: {
                Label("Add Tag", systemImage: "plus")
            }
        }
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
               // .frame(maxWidth: .infinity)
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
