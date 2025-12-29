import SwiftUI

// cp-2025-12-29-02(SETTINGS-TABS-HOSTFIX)

struct DMPPCropPreferencesView: View {

    /// User-level preferences (loaded from UserDefaults).
    @State private var prefs: DMPPUserPreferences = .load()

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

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        locationsSection
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
                Label("Locations", systemImage: "mappin.and.ellipse")
            }
            
            // =====================================================
            // PEOPLE TAB
            // =====================================================

            // IMPORTANT:
            // When embedded in Settings’ TabView, use the .settingsTab host so
            // we *don’t* run a NavigationSplitView inside the TabView.
            // That’s what was causing the tab strip to “shift right” and mis-route clicks.
            DMPPPeopleManagerView(host: .settingsTab)
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
        // Let the user resize; don't clamp maxWidth.
        .frame(minWidth: 520, idealWidth: 800, minHeight: 760, idealHeight: 860)
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

    // MARK: - Tags section (Tags tab)

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

    // MARK: - Locations section (Locations tab)

    private var locationsSection: some View {
        VStack(alignment: .leading, spacing: 10) {

            Text("Saved locations appear in the Location dropdown in the editor.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if prefs.userLocations.isEmpty {
                Text("No saved locations yet. Click “Add Location”.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            } else {
                VStack(alignment: .leading, spacing: 12) {

                    ForEach($prefs.userLocations) { $loc in
                        GroupBox {
                            VStack(alignment: .leading, spacing: 10) {

                                HStack(spacing: 10) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Short Name")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        TextField("", text: $loc.shortName)
                                            .textFieldStyle(.roundedBorder)
                                    }

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Description")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        TextField("", text: nonOptional($loc.description))
                                            .textFieldStyle(.roundedBorder)
                                    }

                                    Spacer()

                                    Button(role: .destructive) {
                                        deleteUserLocation($loc.wrappedValue)
                                    } label: {
                                        Image(systemName: "trash")
                                    }

                                    .buttonStyle(.borderless)
                                    .help("Delete location")
                                }

                                VStack(alignment: .leading, spacing: 10) {

                                    HStack(spacing: 10) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Street Address")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                            TextField("", text: nonOptional($loc.streetAddress))
                                                .textFieldStyle(.roundedBorder)
                                        }

                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("City")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                            TextField("", text: nonOptional($loc.city))
                                                .textFieldStyle(.roundedBorder)
                                                .frame(width: 100)
                                        }
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("State")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                            TextField("", text: nonOptional($loc.state))
                                                .textFieldStyle(.roundedBorder)
                                                .frame(width: 50)
                                        }

                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Country")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                            TextField("", text: nonOptional($loc.country))
                                                .textFieldStyle(.roundedBorder)
                                                .frame(width: 100)
                                        }
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .padding(.top, 4)
            }

            HStack(spacing: 10) {
                Button {
                    addBlankUserLocation()
                } label: {
                    Label("Add Location", systemImage: "plus")
                }

                Button(role: .destructive) {
                    prefs.userLocations.removeAll()
                } label: {
                    Text("Clear All")
                }
                .disabled(prefs.userLocations.isEmpty)

                Spacer()
            }
            .padding(.top, 6)
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
