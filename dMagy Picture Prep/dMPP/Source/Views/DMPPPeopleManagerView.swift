import SwiftUI

// cp-2025-12-18-34(PEOPLE-MANAGER-FULLFILE)

/// Standalone window for managing dMPMS identities.
/// Uses the shared `DMPPIdentityStore` singleton as its backing store.
struct DMPPPeopleManagerView: View {

    // cp-2025-12-29-01(PEOPLE-HOST-MODE)
    enum Host {
        case window        // standalone People Manager window
        case settingsTab   // embedded in Settings TabView
    }

    let host: Host

    init(host: Host = .window) {
        self.host = host
    }

    // Shared store – NOT a Binding, not @Bindable.
    // (Keeping singleton here avoids environment-object wiring churn.)
    @EnvironmentObject private var identityStore: DMPPIdentityStore


    @State private var searchText: String = ""
    @State private var selectedPersonID: String? = nil

    // Drafts for the selected person (birth first, then additional versions)
    @State private var draftBirth: DmpmsIdentity? = nil
    @State private var draftAdditional: [DmpmsIdentity] = []

    @State private var refreshToken = UUID()   // used to force List refresh after edits

    // Delete confirmation
    @State private var showDeleteConfirm: Bool = false
    @State private var deleteTargetPersonID: String? = nil

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
        Group {
            if host == .settingsTab {
                // No NavigationSplitView here — and NO fixed minWidth.
                HSplitView {
                    leftPane
                        .padding(8)                          // small, controlled padding
                        .frame(minWidth: 300, idealWidth: 300, maxWidth: 300)

                    detailEditor
                        .padding(12)                         // matches your other tabs nicely
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            } else {
                // Standalone window behavior (your current approach)
                NavigationSplitView {
                    leftPane
                        .id(refreshToken)
                        .navigationSplitViewColumnWidth(min: 300, ideal: 300, max: 300)
                } detail: {
                    detailEditor
                }
                .frame(minWidth: 910,  minHeight: 660)
            }
        }
        .alert("Delete person?", isPresented: $showDeleteConfirm) { /* unchanged */ } message: { /* unchanged */ }
        .onAppear { /* unchanged */ }
        .onChange(of: selectedPersonID) { _, newValue in /* unchanged */ }
        .onChange(of: identityStore.peopleSortedForUI.count) { _, _ in
            if let pid = selectedPersonID {
                loadDrafts(for: pid)
            } else if let first = filteredPeople.first {
                selectedPersonID = first.id
                loadDrafts(for: first.id)
            }
        }
        .onAppear {
            identityStore.load()

            if selectedPersonID == nil, let first = filteredPeople.first {
                selectedPersonID = first.id
            }
            if let pid = selectedPersonID {
                loadDrafts(for: pid)
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


    // MARK: - Host containers

    // cp-2025-12-29-01(PEOPLE-CONTAINER-SWITCH)
    @ViewBuilder
    private var contentView: some View {
  
        switch host {
        case .window:
            NavigationSplitView {
                leftPane
                    .id(refreshToken)
                    .navigationSplitViewColumnWidth(min: 300, ideal: 300, max: 300) // fixed
            } detail: {
                detailEditor
            }
            .navigationSplitViewStyle(.balanced)
            .frame(minWidth: 880, idealWidth: 880, minHeight: 600)

        case .settingsTab:
            // IMPORTANT:
            // NavigationSplitView inside a TabView/Settings can cause toolbar/tab hit-testing weirdness
            // and “tab strip shifts right”. Use HSplitView instead when embedded.
            HSplitView {
                leftPane
                    .id(refreshToken)
                    .frame(minWidth: 300, idealWidth: 320, maxWidth: 360)

                detailEditor
                    .frame(minWidth: 420, maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
          //  .padding(.top, 8)
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
                 //   let deathDate = deathEventDate(from: versions)
                    let isPet = isPetPerson(versions)

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

                                // Option B: Death is an event; display from Death event date
                             //   if let deathDate, !deathDate.isEmpty {
                            //        Text("(d. \(deathDate))")
                                //        .font(.caption)
                                 //       .foregroundStyle(.secondary)
                           //     }

                                Spacer()

                                if versions.count > 1 {
                                    Text("\(versions.count) identities")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            if let current {

                                HStack(spacing: 4) {
                                    Text(current.fullName)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)

                                    if isPet {
                                        Image(systemName: "pawprint.fill")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                            .accessibilityLabel("Pet")
                                    }
                                }

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

            // Add person moved to bottom of list view
            Button {
                createNewPerson()
            } label: {
                Label("Add person", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .help("Create a new person (birth identity first)")
          //  .padding(.top, 4)
        }
      //  .padding()
    }

    private var filteredPeople: [DMPPIdentityStore.PersonSummary] {
        // Force deterministic ordering (even when names tie)
        let basePeople = identityStore.peopleSortedForUI.sorted(by: peopleSort)

        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return basePeople }

        let needle = trimmed.lowercased()

        // Filtering preserves the incoming order, so no re-sort needed
        return basePeople.filter { person in
            // Person-level fields
            if person.shortName.lowercased().contains(needle) { return true }
            if let notes = person.notes?.lowercased(), notes.contains(needle) { return true }
            if let birth = person.birthDate?.lowercased(), birth.contains(needle) { return true }

            // Any identity version fields (Death is covered by idReason/idDate)
            let versions = identityStore.identityVersions(forPersonID: person.id)
            return versions.contains { v in
                v.fullName.lowercased().contains(needle)
                || v.givenName.lowercased().contains(needle)
                || (v.middleName?.lowercased().contains(needle) ?? false)
                || v.surname.lowercased().contains(needle)
                || v.idReason.lowercased().contains(needle)
                || v.idDate.lowercased().contains(needle)
                || (v.notes?.lowercased().contains(needle) ?? false)
                || v.kind.lowercased().contains(needle)
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
                    Text("Select a person on the left, or use “Add person” to create one.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            //    .padding()

            } else if draftBirth == nil {
                VStack(alignment: .leading, spacing: 8) {
                    Text("No birth identity found")
                        .font(.headline)
                    Text("This shouldn’t happen. Try creating a new person.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
           //     .padding()

            } else {
                VStack(alignment: .leading, spacing: 12) {

                    GroupBox {
                        VStack(alignment: .leading, spacing: 7) {

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
                                    "Relationships, roles, etc.)",
                                    text: optionalBindingBirth(\.notes)
                                )
                            }
                        }
                    .padding(8)
                    }

                    HStack {
                        // Delete moved here, left of Add event, with spacer in between
                        Button(role: .destructive) {
                            deleteTargetPersonID = selectedPersonID
                            showDeleteConfirm = true
                        } label: {
                            Label("Delete person", systemImage: "trash")
                        }
                        .disabled(selectedPersonID == nil)
                        .buttonStyle(.bordered)

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

            // LINE 1: Short name + Birth date + Kind + Favorite
            HStack(alignment: .top, spacing: 12) {

                VStack(alignment: .leading, spacing: 2) {
                    Text("Short name")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField( "Short name", text: bindingBirth(\.shortName))
                        .frame(width: 160)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Birth Date")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("YYYY-MM-DD", text: optionalBindingBirth(\.birthDate))
                        .frame(width: 160)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Kind")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Picker("Kind", selection: kindBindingBirth()) {
                        Text("Human").tag("human")
                        Text("Pet").tag("pet")
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: 120, alignment: .leading)
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
                        .frame(width: 160)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Aliases")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("Comma-separated (e.g., Elizabeth, Betty Ann)", text: aliasesBindingBirth())
                        .frame(width: 320)
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
                        .frame(width: 160)
                    TextField("Middle", text: optionalBindingBirth(\.middleName))
                        .frame(width: 160)
                    TextField("Surname", text: bindingBirth(\.surname))
                        .frame(width: 160)
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
                                            .frame(width: 150)
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
                                    .frame(width: 155)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text("")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)

                                Button(role: .destructive) {
                                    removeAdditionalIdentity(id: identity.id)
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                                .buttonStyle(.bordered)
                            }
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
                                        .frame(width: 155)

                                    TextField(
                                        "Middle",
                                        text: Binding(
                                            get: { identity.middleName ?? "" },
                                            set: { identity.middleName = $0.isEmpty ? nil : $0 }
                                        )
                                    )
                                    .frame(width: 155)

                                    TextField("Surname", text: $identity.surname)
                                        .frame(width: 155)
                                }
                            }
                        } else if isDeath {
                            Text("Death does not create a new name. (Name fields are not shown.)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
             //       .padding(10)
                    .background(.quaternary.opacity(0.35))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
    }

    // MARK: - Actions

    private func createNewPerson() {
        let newPersonID = identityStore.addPerson()
        selectedPersonID = newPersonID
        loadDrafts(for: newPersonID)
        refreshToken = UUID()
    }

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

    private func peopleSort(_ a: DMPPIdentityStore.PersonSummary,
                            _ b: DMPPIdentityStore.PersonSummary) -> Bool {
        let nameA = a.shortName.trimmingCharacters(in: .whitespacesAndNewlines)
        let nameB = b.shortName.trimmingCharacters(in: .whitespacesAndNewlines)

        let c = nameA.localizedCaseInsensitiveCompare(nameB)
        if c != .orderedSame { return c == .orderedAscending }

        let bdA = (a.birthDate ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let bdB = (b.birthDate ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if bdA != bdB { return bdA < bdB }

        // Final deterministic tie-breaker (prevents “two Annas swap places”)
        return a.id < b.id
    }

    private func addIdentityVersion(for personID: String) {
        _ = identityStore.addIdentityVersion(forPersonID: personID)
        loadDrafts(for: personID)
        refreshToken = UUID()
    }

    private func deletePerson(personID pid: String) {
        identityStore.deletePerson(personID: pid)

        refreshToken = UUID()

        // Auto-select a remaining person
        let remaining = filteredPeople
        if let first = remaining.first {
            selectedPersonID = first.id
            loadDrafts(for: first.id)
        } else {
            selectedPersonID = nil
            draftBirth = nil
            draftAdditional = []
        }
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

    private func kindBindingBirth() -> Binding<String> {
        Binding<String>(
            get: {
                let raw = (draftBirth?.kind ?? "human")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased()
                return (raw == "pet") ? "pet" : "human"
            },
            set: { newValue in
                draftBirth?.kind = (newValue == "pet") ? "pet" : "human"
            }
        )
    }

    // MARK: - Death as event helper (Option B)

    private func deathEventDate(from versions: [DmpmsIdentity]) -> String? {
        // If multiple Death events exist, prefer the latest by sortable date key.
        let deaths = versions.filter { $0.idReason.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "death" }
        guard !deaths.isEmpty else { return nil }

        let best = deaths.max(by: { sortKeyLocal($0.idDate) < sortKeyLocal($1.idDate) })
        let s = (best?.idDate ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return s.isEmpty ? nil : s
    }

    // MARK: - Kind helpers

    private func isPetPerson(_ versions: [DmpmsIdentity]) -> Bool {
        let birth = versions.first(where: { $0.idReason.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "birth" })
            ?? versions.first
        let raw = (birth?.kind ?? "human").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return raw == "pet"
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
    DMPPPeopleManagerView(host: .window)
}
