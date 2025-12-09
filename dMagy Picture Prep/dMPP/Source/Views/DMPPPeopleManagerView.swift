//
//  DMPPPeopleManagerView.swift
//  dMagy Picture Prep
//
//  dMPP-2025-12-09-PEOPLE-MGR-V1 — Read-only People Manager window
//

import SwiftUI

struct DMPPPeopleManagerView: View {

    // Simple search/filter text
    @State private var searchText: String = ""

    // For now we just talk to the singleton store directly.
    // Later we can make this @Environment-driven if we want.
    private var store: DMPPIdentityStore { .shared }

    /// Identities sorted for UI, then filtered by search text.
    private var filteredIdentities: [DmpmsIdentity] {
        let all = store.identitiesSortedForUI
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return all }

        let q = query.lowercased()
        return all.filter { identity in
            identity.shortName.lowercased().contains(q)
            || identity.fullName.lowercased().contains(q)
            || (identity.notes?.lowercased().contains(q) ?? false)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // -------------------------------------------------
            // Header / toolbar row
            // -------------------------------------------------
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("People Manager")
                        .font(.title2.bold())

                    Text(summaryLine)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Simple search field
                TextField("Search people…", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 240)
            }
            .padding(.bottom, 4)

            Divider()

            // -------------------------------------------------
            // Table of identities
            // -------------------------------------------------
            if filteredIdentities.isEmpty {
                Text("No identities match your search.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                Table(filteredIdentities) {
                    TableColumn("Short", value: \.shortName)
                        .width(min: 80, ideal: 100, max: 120)

                    TableColumn("Full Name") { identity in
                        Text(identity.fullName)
                    }

                    TableColumn("Birth") { identity in
                        if let birth = identity.birthDate, !birth.isEmpty {
                            Text(birth)
                        } else {
                            Text("—")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .width(min: 90, ideal: 110, max: 140)

                    TableColumn("From") { identity in
                        if identity.idDate.isEmpty {
                            Text("—")
                                .foregroundStyle(.secondary)
                        } else {
                            Text(identity.idDate)
                        }
                    }
                    .width(min: 90, ideal: 110, max: 140)


                    TableColumn("Reason") { identity in
                        let reason = identity.idReason.trimmingCharacters(in: .whitespacesAndNewlines)

                        if reason.isEmpty {
                            Text("—")
                                .foregroundStyle(.secondary)
                        } else {
                            Text(reason)
                        }
                    }
                    .width(min: 80, ideal: 100, max: 140)


                    TableColumn("Favorite") { identity in
                        if identity.isFavorite {
                            Image(systemName: "star.fill")
                                .foregroundStyle(.yellow)
                        } else {
                            Image(systemName: "star")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .width(60)
                }
            }
        }
        .padding()
        .frame(
            minWidth: 700,
            minHeight: 400
        )
    }

    // MARK: - Helpers

    private var summaryLine: String {
        let count = store.identities.count
        switch count {
        case 0:
            return "No identities defined yet."
        case 1:
            return "You have 1 identity in your registry."
        default:
            return "You have \(count) identities in your registry."
        }
    }
}

// MARK: - Preview

#Preview {
    DMPPPeopleManagerView()
}
