//
//  DMPPCropPreferencesView.swift
//  dMagy Picture Prep
//
//  dMPP-2025-11-30-PREF-UI1 — Default crop preferences UI
//

import SwiftUI

struct DMPPCropPreferencesView: View {

    // Load once; we’ll save on each change.
    @State private var prefs: DMPPUserPreferences = .load()

    private let allPresets = DMPPUserPreferences.CropPresetID.allCases

    var body: some View {
        Form {
            Section("Default crops for new images") {
                Text("Choose which crops are created automatically when an image has no saved settings. You can still add other crops later per picture.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                ForEach(allPresets, id: \.self) { preset in
                    Toggle(isOn: binding(for: preset)) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(preset.displayName)
                            if let detail = preset.detailText {
                                Text(detail)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Text("If you turn everything off, dMPP will still create a single “Original (full image)” crop so you can use it just for metadata.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }

            Section {
                Button("Restore default selection") {
                    prefs.defaultCropPresets = [
                        .landscape16x9,
                        .portrait8x10
                    ]
                    prefs.save()
                }
            }
        }
        .padding()
        .frame(minWidth: 360, idealWidth: 420, minHeight: 320)
    }

    // MARK: - Helpers

    private func binding(for preset: DMPPUserPreferences.CropPresetID) -> Binding<Bool> {
        Binding(
            get: {
                prefs.defaultCropPresets.contains(preset)
            },
            set: { isOn in
                if isOn {
                    if !prefs.defaultCropPresets.contains(preset) {
                        prefs.defaultCropPresets.append(preset)
                    }
                } else {
                    prefs.defaultCropPresets.removeAll { $0 == preset }
                }
                // Persist immediately on change
                prefs.save()
            }
        )
    }
}

// MARK: - Friendly labels for each preset

extension DMPPUserPreferences.CropPresetID {

    var displayName: String {
        switch self {
        case .original:
            return "Original (full image)"
        case .landscape16x9:
            return "Landscape 16:9"
        case .portrait8x10:
            return "Portrait 8×10"
        case .headshot8x10:
            return "Headshot 8×10"
        case .landscape4x6:
            return "Landscape 4×6"
        case .square1x1:
            return "Square 1:1"
        }
    }

    var detailText: String? {
        switch self {
        case .original:
            return "Keeps the entire photo visible; good when you only want metadata."
        case .landscape16x9:
            return "Ideal for TVs and widescreen displays."
        case .portrait8x10:
            return "Classic portrait ratio for prints and frames."
        case .headshot8x10:
            return "Portrait ratio with headshot guides for consistent faces."
        case .landscape4x6:
            return "Traditional photo print ratio."
        case .square1x1:
            return "Square, flexible for social and mixed layouts."
        }
    }
}

#Preview {
    DMPPCropPreferencesView()
}
