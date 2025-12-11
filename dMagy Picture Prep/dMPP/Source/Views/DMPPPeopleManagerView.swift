//
//  DMPPPeopleManagerView.swift
//  dMagy Picture Prep
//
//  dMPP-2025-12-09-PPL-MGR3 — People Manager aligned with current DmpmsIdentity
//

import SwiftUI

struct DMPPPeopleManagerView: View {

    // Search/filter text
    @State private var searchText: String = ""

    // Shared identity store (singleton)
    @State private var identityStore = DMPPIdentityStore.shared

    // Currently selected identity (by id)
    @State private var selectedIdentityID: String? = nil

    // Editable copy of the selected identity
    @State private var draftIdentity: DmpmsIdentity? = nil

    // MARK: - Derived data

    /// Identities sorted for UI, then filtered by search text.
    private var filteredIdentities: [DmpmsIdentity] {
        let all = identityStore.identitiesSortedForUI
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else { return all }

        let lower = trimmed.lowercased()
        return all.filter { identity in
            identity.shortName.lowercased().contains(lower) ||
            identity.fullName.lowercased().contains(lower) ||
            (identity.notes?.lowercased().contains(lower) ?? false)
        }
    }

    // Common identity-change events used to seed the Event picker.
    // This is just a suggestion list; users can still type any text.
    private let eventSuggestions: [String] = [
        "Birth",
        "Marriage",
        "Divorce",
        "Name Change",
        "Adoption",
        "Legal Change",
        "Other"
    ]

    
    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("People Manager")
                        .font(.title2.bold())
                    Text("You have \(identityStore.identitiesSortedForUI.count) identities in your registry.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            // Search row
            HStack(spacing: 8) {
                TextField("Search by short name, full name, or notes", text: $searchText)
                    .textFieldStyle(.roundedBorder)

                Button {
                    // Clear search quickly
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .opacity(searchText.isEmpty ? 0.0 : 0.5)
                }
                .buttonStyle(.borderless)
                .disabled(searchText.isEmpty)
                .help("Clear search")
            }

            Divider()

            // Main 2-column layout: list on the left, detail editor on the right
            HStack(alignment: .top, spacing: 16) {

                // LEFT: identity list
                identityList
                    .frame(minWidth: 260, maxWidth: 320, maxHeight: .infinity)

                // RIGHT: detail editor
                detailEditor
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .padding()
        .onChange(of: selectedIdentityID) { _, newID in
            // Load the selected identity into the draft editor
            if let id = newID,
               let identity = identityStore.identity(withID: id) {
                draftIdentity = identity
            } else {
                draftIdentity = nil
            }
        }
        .onChange(of: draftIdentity) { _, newDraft in
            // Auto-save changes to the store whenever the draft changes
            guard let updated = newDraft else { return }
            identityStore.upsert(updated)
        }
    }

    // MARK: - Left: Identity list

    private var identityList: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Identities")
                    .font(.headline)
                Spacer()
            }

            if filteredIdentities.isEmpty {
                Text("No identities match your search.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            } else {
                List(selection: $selectedIdentityID) {
                    ForEach(filteredIdentities) { identity in
                        HStack(alignment: .center, spacing: 8) {

                            // Favorite star next to short name
                            Button {
                                var updated = identity
                                updated.isFavorite.toggle()
                                identityStore.upsert(updated)
                            } label: {
                                Image(systemName: identity.isFavorite ? "star.fill" : "star")
                                    .foregroundStyle(identity.isFavorite ? .yellow : .secondary)
                                    .help("Mark as favorite")
                            }
                            .buttonStyle(.plain)

                            // Short name + full name
                            VStack(alignment: .leading, spacing: 2) {
                                Text(identity.shortName)
                                    .font(.headline)

                                Text(identity.fullName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            // Optional small birth date on the right, if present
                            if let birthDate = identity.birthDate, !birthDate.isEmpty {
                                Text(birthDate)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                        .contentShape(Rectangle())
                    }


                }
                .listStyle(.inset)
            }
        }
    }

    // MARK: - Right: Detail editor

    private var detailEditor: some View {
        Group {
            if let _ = draftIdentity {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Details")
                            .font(.headline)
                        Spacer()
                        deleteButton
                    }

                    GroupBox {
                        VStack(alignment: .leading, spacing: 8) {

                            // Short name + favorite star
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Short name")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                HStack(spacing: 6) {
                                    TextField("Short name", text: binding(\.shortName))

                                    // Favorite star inline with short name
                                    Button {
                                        var current = binding(\.isFavorite).wrappedValue
                                        current.toggle()
                                        binding(\.isFavorite).wrappedValue = current
                                    } label: {
                                        let isFavorite = binding(\.isFavorite).wrappedValue
                                        Image(systemName: isFavorite ? "star.fill" : "star")
                                            .foregroundStyle(isFavorite ? .yellow : .secondary)
                                            .help(isFavorite ? "Unmark as favorite" : "Mark as favorite")
                                    }
                                    .buttonStyle(.plain)
                                }
                            }

                            // Name components
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Name")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                HStack(spacing: 6) {
                                    TextField("Given", text: binding(\.givenName))
                                    TextField("Middle", text: optionalBinding(\.middleName))
                                        .frame(width: 120)
                                    TextField("Surname", text: binding(\.surname))
                                }
                            }

                            // Event & Dates
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Event & Dates")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                HStack(spacing: 6) {

                                    // EVENT (reason)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Event")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)

                                        Picker("Event", selection: binding(\.idReason)) {
                                            // Allow empty / custom
                                            Text("—").tag("")
                                            ForEach(eventSuggestions, id: \.self) { suggestion in
                                                Text(suggestion).tag(suggestion)
                                            }
                                        }
                                        .labelsHidden()
                                        .frame(width: 150)
                                        .focusable(true)   // ensure it participates in tab order on macOS
                                    }

                                    // EVENT DATE (idDate)
                                    VStack(alignment: .leading, spacing: 0) {
                                        Text("Event Date")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)

                                        TextField(
                                            "YYYY-MM-DD",
                                            text: Binding(
                                                get: { draftIdentity?.idDate ?? "" },
                                                set: { newValue in
                                                    // Always update idDate
                                                    draftIdentity?.idDate = newValue

                                                    // If this is a Birth event, keep Birth Date in sync
                                                    if draftIdentity?.idReason.lowercased() == "birth" {
                                                        let trimmed = newValue
                                                            .trimmingCharacters(in: .whitespacesAndNewlines)
                                                        draftIdentity?.birthDate = trimmed.isEmpty ? nil : trimmed
                                                    }
                                                }
                                            )
                                        )
                                    }

                                    // BIRTH DATE
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Birth Date")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)

                                        TextField("YYYY-MM-DD", text: optionalBinding(\.birthDate))
                                    }
                                }
                            }

                            // Notes
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Notes")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                TextField(
                                    "Notes (relationships, roles, etc.)",
                                    text: optionalBinding(\.notes)
                                )
                            }
                        }
                        .padding(8)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("No person selected")
                        .font(.headline)
                    Text("Select an identity on the left to view or edit details.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }


    // MARK: - Delete button

    private var deleteButton: some View {
        Button(role: .destructive) {
            guard let id = draftIdentity?.id else { return }
            identityStore.delete(identityID: id)
            selectedIdentityID = nil
            draftIdentity = nil
        } label: {
            Image(systemName: "trash")
        }
        .help("Delete this identity from the registry")
        .buttonStyle(.borderless)
        .disabled(draftIdentity == nil)
    }

    // MARK: - Binding helpers for draftIdentity

    /// Simple binding for non-optional String properties on `DmpmsIdentity`.
    private func binding(_ keyPath: WritableKeyPath<DmpmsIdentity, String>) -> Binding<String> {
        Binding<String>(
            get: {
                draftIdentity?[keyPath: keyPath] ?? ""
            },
            set: { newValue in
                draftIdentity?[keyPath: keyPath] = newValue
            }
        )
    }

    /// Binding for optional String properties on `DmpmsIdentity`,
    /// treating empty string as `nil`.
    private func optionalBinding(_ keyPath: WritableKeyPath<DmpmsIdentity, String?>) -> Binding<String> {
        Binding<String>(
            get: {
                draftIdentity?[keyPath: keyPath] ?? ""
            },
            set: { newValue in
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                draftIdentity?[keyPath: keyPath] = trimmed.isEmpty ? nil : trimmed
            }
        )
    }

    /// Binding for Bool properties on `DmpmsIdentity`.
    private func binding(_ keyPath: WritableKeyPath<DmpmsIdentity, Bool>) -> Binding<Bool> {
        Binding<Bool>(
            get: {
                draftIdentity?[keyPath: keyPath] ?? false
            },
            set: { newValue in
                draftIdentity?[keyPath: keyPath] = newValue
            }
        )
    }
}

// MARK: - Preview

#Preview {
    DMPPPeopleManagerView()
}
