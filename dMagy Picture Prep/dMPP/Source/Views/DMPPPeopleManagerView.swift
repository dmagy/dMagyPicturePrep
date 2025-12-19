import SwiftUI

// cp-2025-12-18-34(PEOPLE-MANAGER-FULLFILE)

/// Standalone window for managing dMPMS identities.
/// Uses the shared `DMPPIdentityStore` singleton as its backing store.
struct DMPPPeopleManagerView: View {

    // Shared store – NOT a Binding, not @Bindable.
    private let identityStore = DMPPIdentityStore.shared

    @State private var searchText: String = ""
    @State private var selectedPersonID: String? = nil

    // Drafts for the selected person (birth first, then additional versions)
    @State private var draftBirth: DmpmsIdentity? = nil
    @State private var draftAdditional: [DmpmsIdentity] = []

    @State private var refreshToken = UUID()   // used to force List refresh after edits

    // Default event suggestions for additional identity versions.
    // (Birth is handled by the birth identity block.)
    private let eventSuggestions = [
        "Adoption",
        "Anglicization",
        "Baptism",
        "Confirmation",
        "Correction of record",
        "Court-ordered",
        "Death",
        "Diacritics changed",
        "Divorce",
        "Gender transition",
        "Legal name change",
        "Localization",
        "Marriage",
        "Name Change",
        "Name Variant",
        "Paternity established",
        "Pen name",
        "Religious conversion",
        "Spelling correction",
        "Stage name",
        "Transliteration",
        "Witness protection"
    ]

    var body: some View {
        NavigationSplitView {
            leftPane
                .id(refreshToken)
                .navigationSplitViewColumnWidth(min: 320, ideal: 320, max: 320) // fixed
        } detail: {
            detailEditor
        }
        .frame(minWidth: 900, minHeight: 500)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    let newPersonID = identityStore.addPerson()
                    selectedPersonID = newPersonID
                    loadDrafts(for: newPersonID)
                    refreshToken = UUID()
                } label: {
                    Label("New Person", systemImage: "plus")
                }
                .help("Create a new person (birth identity first)")
            }
        }
        .onAppear {
            identityStore.load()

            // If nothing is selected yet, preselect first person.
            if selectedPersonID == nil, let first = filteredPeople.first {
                selectedPersonID = first.id
                loadDrafts(for: first.id)
            }
        }
        .onChange(of: selectedPersonID) { _, newValue in
            if let pid = newValue {
                loadDrafts(for: pid)
            } else {
                draftBirth = nil
                draftAdditional = []
            }
        }
    }

    // MARK: - Left pane (list + search)

    private var leftPane: some View {
        VStack(alignment: .leading, spacing: 8) {

            TextField("Search by short name, names, event, or notes", text: $searchText)
                .textFieldStyle(.roundedBorder)

            List(selection: $selectedPersonID) {
                ForEach(filteredPeople) { person in
                    let versions = identityStore.identityVersions(forPersonID: person.id)
                    let current = versions.last ?? versions.first

                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: person.isFavorite ? "star.fill" : "star")
                            .foregroundStyle(person.isFavorite ? .yellow : .secondary)
                            .help(person.isFavorite ? "Favorite" : "Not marked favorite")

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 8) {
                                Text(person.shortName.isEmpty ? "Untitled" : person.shortName)
                                    .font(.headline)

                                if let birth = person.birthDate, !birth.isEmpty {
                                    Text("(b. \(birth))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                if let death = person.versions.first?.deathDate {
                                    let deathClean = death.trimmingCharacters(in: .whitespacesAndNewlines)
                                    if !deathClean.isEmpty {
                                        Text("(d. \(deathClean))")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }


                                Spacer()

                                if versions.count > 1 {
                                    Text("\(versions.count) identities")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            if let current {
                                Text(current.fullName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                // Show latest event (if not Birth)
                                if !current.idReason.isEmpty,
                                   current.idReason.lowercased() != "birth" {
                                    HStack(spacing: 6) {
                                        Text(current.idReason)
                                            .font(.caption2)
                                        if !current.idDate.isEmpty {
                                            Text(current.idDate)
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }

                            if let notes = person.notes, !notes.isEmpty {
                                Text(notes)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .tag(person.id)
                }
            }

            HStack {
                Button(role: .destructive) {
                    deleteSelectedPerson()
                } label: {
                    Label("Delete person", systemImage: "trash")
                }
                .disabled(selectedPersonID == nil)
            }
            .padding(.top, 4)

        }
        .padding()
    }

    private var filteredPeople: [DMPPIdentityStore.PersonSummary] {
        let all = identityStore.peopleSortedForUI

        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return all }

        let needle = trimmed.lowercased()

        return all.filter { person in
            // Person-level fields
            if person.shortName.lowercased().contains(needle) { return true }
            if let notes = person.notes?.lowercased(), notes.contains(needle) { return true }
            if let birth = person.birthDate?.lowercased(), birth.contains(needle) { return true }

            // Any identity version fields
            let versions = identityStore.identityVersions(forPersonID: person.id)
            return versions.contains { v in
                v.fullName.lowercased().contains(needle)
                || v.givenName.lowercased().contains(needle)
                || (v.middleName?.lowercased().contains(needle) ?? false)
                || v.surname.lowercased().contains(needle)
                || v.idReason.lowercased().contains(needle)
                || v.idDate.lowercased().contains(needle)
                || (v.notes?.lowercased().contains(needle) ?? false)
                || (v.deathDate?.lowercased().contains(needle) ?? false)
            }
        }
    }

    // MARK: - Right pane (detail editor)

    private var detailEditor: some View {
        Group {
            if selectedPersonID == nil {
                VStack(alignment: .leading, spacing: 8) {
                    Text("No person selected")
                        .font(.headline)
                    Text("Select a person on the left, or click “New person” to add one.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()

            } else if draftBirth == nil {
                VStack(alignment: .leading, spacing: 8) {
                    Text("No birth identity found")
                        .font(.headline)
                    Text("This shouldn’t happen. Try creating a new person.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()

            } else {
                VStack(alignment: .leading, spacing: 12) {

                    GroupBox {
                        VStack(alignment: .leading, spacing: 14) {

                            // BIRTH IDENTITY (always first)
                            birthEditorSection

                            Divider()

                            // ADDITIONAL IDENTITIES (repeat blocks)
                            additionalIdentitiesSection

                            Divider()

                            // Notes (person-level; store keeps synced across versions)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Notes")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                TextField(
                                    "Notes (relationships, roles, variants, etc.)",
                                    text: optionalBindingBirth(\.notes)
                                )
                            }
                        }
                        .padding(12)
                    }

                    HStack {
                        Spacer()

                        Button("Add event…") {
                            if let pid = selectedPersonID {
                                addIdentityVersion(for: pid)
                            }
                        }

                        Button("Save") {
                            if let pid = selectedPersonID {
                                saveAllDrafts(for: pid)
                            }
                        }
                        .keyboardShortcut("s", modifiers: [.command])
                    }
                    .padding(.top, 8)

                    Spacer()
                }
                .padding()
            }
        }
    }

    private var birthEditorSection: some View {
        VStack(alignment: .leading, spacing: 10) {

            // LINE 1: Short name + Birth date + Death date + Favorite
            HStack(alignment: .top, spacing: 12) {

                VStack(alignment: .leading, spacing: 2) {
                    Text("Short name")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("Short name", text: bindingBirth(\.shortName))
                        .frame(width: 180)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Birth Date")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("YYYY-MM-DD", text: optionalBindingBirth(\.birthDate))
                        .frame(width: 120)
                }

                // cp-2025-12-18-34(DEATHDATE-UI)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Death Date")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("YYYY-MM-DD", text: optionalBindingBirth(\.deathDate))
                        .frame(width: 120)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Favorite")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Toggle(isOn: boolBindingBirth(\.isFavorite)) {
                        Image(systemName: (draftBirth?.isFavorite ?? false) ? "star.fill" : "star")
                            .foregroundStyle((draftBirth?.isFavorite ?? false) ? .yellow : .secondary)
                    }
                    .toggleStyle(.button)
                    .help("Mark this person as a favorite for quick access.")
                }
                .frame(width: 80, alignment: .leading)
            }

            // LINE 1b: Preferred + Aliases (person-level)
            HStack(spacing: 12) {

                VStack(alignment: .leading, spacing: 2) {
                    Text("Preferred")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("e.g., Betty", text: optionalBindingBirth(\.preferredName))
                        .frame(width: 180)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Aliases")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("Comma-separated (e.g., Elizabeth, Betty Ann)", text: aliasesBindingBirth())
                }

                Spacer()
            }

            // LINE 2: Given / Middle / Surname at birth
            VStack(alignment: .leading, spacing: 4) {
                Text("Name at birth")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    TextField("Given", text: bindingBirth(\.givenName))
                    TextField("Middle", text: optionalBindingBirth(\.middleName))
                        .frame(width: 140)
                    TextField("Surname", text: bindingBirth(\.surname))
                }
            }
        }
    }

    private var additionalIdentitiesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Life events")
                .font(.caption)
                .foregroundStyle(.secondary)

            if draftAdditional.isEmpty {
                Text("None yet. Click “Add event…” to add marriage/name-change/etc.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                ForEach($draftAdditional, id: \.id) { $identity in
                    VStack(alignment: .leading, spacing: 8) {

                        // Event + Event Date + Remove (same row)
                        HStack(alignment: .top, spacing: 10) {

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Event")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)

                                Picker("Event", selection: $identity.idReason) {
                                    Text("—").tag("")
                                    ForEach(eventSuggestions, id: \.self) { suggestion in
                                        Text(suggestion).tag(suggestion)
                                    }
                                }
                                .labelsHidden()
                                .frame(width: 160)
                                // cp-2025-12-18-34(DEATH-AUTOCOPY)
                                .onChange(of: identity.idReason) { _, newValue in
                                    let r = newValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                                    guard r == "death" else { return }

                                    // Death does not create a new name.
                                    // Copy the latest known name from birth or the most recent additional identity.
                                    guard let birth = draftBirth else { return }

                                    let candidates = [birth] + draftAdditional.filter { $0.id != identity.id }
                                    let best = candidates.max(by: { sortKeyLocal($0.idDate) < sortKeyLocal($1.idDate) }) ?? birth

                                    identity.givenName = best.givenName
                                    identity.middleName = best.middleName
                                    identity.surname = best.surname
                                }
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Event Date")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)

                                TextField("YYYY-MM-DD", text: $identity.idDate)
                                    .frame(width: 120)
                            }

                            Spacer()

                            Button(role: .destructive) {
                                removeAdditionalIdentity(id: identity.id)
                            } label: {
                                Label("Remove", systemImage: "trash")
                            }
                            .buttonStyle(.bordered)
                        }

                        // cp-2025-12-18-34(DEATH-NO-RENAME)
                        let reason = identity.idReason.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                        let hasEvent = !reason.isEmpty
                        let isDeath = (reason == "death")

                        if hasEvent && !isDeath {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Name at event")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                HStack(spacing: 6) {
                                    TextField("Given", text: $identity.givenName)

                                    TextField(
                                        "Middle",
                                        text: Binding(
                                            get: { identity.middleName ?? "" },
                                            set: { identity.middleName = $0.isEmpty ? nil : $0 }
                                        )
                                    )
                                    .frame(width: 140)

                                    TextField("Surname", text: $identity.surname)
                                }
                            }
                        } else if isDeath {
                            Text("Death does not create a new name. (Name fields are not shown.)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(10)
                    .background(.quaternary.opacity(0.35))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
    }

    // MARK: - Actions

    private func loadDrafts(for personID: String) {
        let versions = identityStore.identityVersions(forPersonID: personID)

        // Pick birth identity if present, otherwise first.
        let birth = versions.first(where: { $0.idReason.lowercased() == "birth" }) ?? versions.first
        draftBirth = birth

        if let birthID = birth?.id {
            draftAdditional = versions.filter { $0.id != birthID }
        } else {
            draftAdditional = versions
        }
    }

    private func removeAdditionalIdentity(id removeID: String) {
        // Remove from UI drafts
        draftAdditional.removeAll { $0.id == removeID }

        // Remove from persistent store
        identityStore.delete(id: removeID)

        // Reload drafts so the right pane reflects store truth
        if let pid = selectedPersonID {
            loadDrafts(for: pid)
        }

        refreshToken = UUID()
    }

    private func addIdentityVersion(for personID: String) {
        _ = identityStore.addIdentityVersion(forPersonID: personID)
        loadDrafts(for: personID)
        refreshToken = UUID()
    }

    private func deleteSelectedPerson() {
        guard let pid = selectedPersonID else { return }
        identityStore.deletePerson(personID: pid)
        selectedPersonID = nil
        draftBirth = nil
        draftAdditional = []
        refreshToken = UUID()
    }

    private func saveAllDrafts(for personID: String) {
        guard let birth = draftBirth else { return }

        // IDs that should exist after save
        let keepIDs = Set([birth.id] + draftAdditional.map { $0.id })

        // Delete any stored versions for this person that are not in the drafts
        let existing = identityStore.identityVersions(forPersonID: personID)
        for v in existing where !keepIDs.contains(v.id) {
            identityStore.delete(id: v.id)
        }

        // Upsert what remains
        identityStore.upsert(birth)
        for v in draftAdditional {
            identityStore.upsert(v)
        }

        refreshToken = UUID()
    }

    // MARK: - Binding helpers (Birth)

    private func bindingBirth(_ keyPath: WritableKeyPath<DmpmsIdentity, String>) -> Binding<String> {
        Binding<String>(
            get: { draftBirth?[keyPath: keyPath] ?? "" },
            set: { newValue in draftBirth?[keyPath: keyPath] = newValue }
        )
    }

    private func optionalBindingBirth(_ keyPath: WritableKeyPath<DmpmsIdentity, String?>) -> Binding<String> {
        Binding<String>(
            get: { draftBirth?[keyPath: keyPath] ?? "" },
            set: { newValue in
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                draftBirth?[keyPath: keyPath] = trimmed.isEmpty ? nil : trimmed
            }
        )
    }

    private func boolBindingBirth(_ keyPath: WritableKeyPath<DmpmsIdentity, Bool>) -> Binding<Bool> {
        Binding<Bool>(
            get: { draftBirth?[keyPath: keyPath] ?? false },
            set: { newValue in draftBirth?[keyPath: keyPath] = newValue }
        )
    }

    private func aliasesBindingBirth() -> Binding<String> {
        Binding<String>(
            get: { (draftBirth?.aliases ?? []).joined(separator: ", ") },
            set: { newValue in
                let parts = newValue
                    .split(whereSeparator: { $0 == "," || $0 == ";" })
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }

                // de-dupe (case-insensitive) while preserving order
                var seen = Set<String>()
                var cleaned: [String] = []
                for p in parts {
                    let key = p.lowercased()
                    if !seen.contains(key) {
                        seen.insert(key)
                        cleaned.append(p)
                    }
                }
                draftBirth?.aliases = cleaned
            }
        )
    }

    // MARK: - Local helper

    // cp-2025-12-18-34(SORTKEY-LOCAL)
    private func sortKeyLocal(_ raw: String) -> Int {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return Int.min }

        // YYYY-MM-DD
        if s.count == 10,
           s[s.index(s.startIndex, offsetBy: 4)] == "-",
           s[s.index(s.startIndex, offsetBy: 7)] == "-" {
            let y = Int(s.prefix(4)) ?? 0
            let m = Int(s.dropFirst(5).prefix(2)) ?? 0
            let d = Int(s.dropFirst(8).prefix(2)) ?? 0
            return y * 10_000 + m * 100 + d
        }

        // YYYY-MM
        if s.count == 7,
           s[s.index(s.startIndex, offsetBy: 4)] == "-" {
            let y = Int(s.prefix(4)) ?? 0
            let m = Int(s.dropFirst(5).prefix(2)) ?? 0
            return y * 10_000 + m * 100 + 1
        }

        // YYYY
        if s.count == 4, let y = Int(s) {
            return y * 10_000 + 1 * 100 + 1
        }

        return Int.min
    }
}

#Preview {
    DMPPPeopleManagerView()
}
