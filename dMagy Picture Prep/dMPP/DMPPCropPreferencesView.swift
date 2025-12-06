//
//  DMPPCropPreferencesView.swift
//  dMagy Picture Prep
//
//  dMPP-2025-12-02-PREF-UI4 — Crop + Tag preferences in tabbed Settings
//

import SwiftUI

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

    // MARK: - Tags section (for Tags tab)

    private var tagsSection: some View {
        Section("Tags") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Tags shown as checkboxes in the editor.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(Array(prefs.availableTags.enumerated()), id: \.offset) { index, tag in
                    // Special styling + behavior for the mandatory tag.
                    if tag == DMPPUserPreferences.mandatoryTagName {
                        HStack {
                            Text(tag)
                                .padding(.leading, 6)          // matches the left inset feel
                                .font(.body)                   // make sure it matches the TextField font

                            Spacer()

                            Image(systemName: "lock.fill")
                                .foregroundStyle(.secondary)   // softer than full black
                                .help("This tag is required and cannot be deleted.")
                        }
                    }
 else {
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
    }


    // MARK: - Helpers

    /// Adds a new, blank-ish custom preset row.
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

    /// Deletes a custom preset safely by ID.
    private func deleteCustomPreset(_ preset: DMPPUserPreferences.CustomCropPreset) {
        prefs.customCropPresets.removeAll { $0.id == preset.id }
    }
}

// MARK: - Preview

#Preview {
    DMPPCropPreferencesView()
}
