import SwiftUI

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
        "Marriage",
        "Divorce",
        "Name Change",
        "Name Variant",
        "Adoption",
        "Legal Name Change"
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
        //    Text("People Manager")
        //       .font(.title2.bold())
//
         //   Text("Manage people identities used for tagging and age calculations.")
        //        .font(.caption)
         //       .foregroundStyle(.secondary)

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

                    
                }
              //  .padding()
                
                HStack {
                    Spacer()

                    Button("Add identity…") {
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
                    .padding()
                    
                }
                Spacer()
            }
        }
    }


    private var birthEditorSection: some View {
        VStack(alignment: .leading, spacing: 10) {

            // LINE 1: Favorite + Short name + Birth date
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
                // Favorite (with caption)
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
              //  Spacer()
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
            Text("Additional identities")
                .font(.caption)
                .foregroundStyle(.secondary)

            if draftAdditional.isEmpty {
                Text("None yet. Click “Add identity…” to add marriage/name-change/etc.")
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
                                let removeID = identity.id
                                draftAdditional.removeAll { $0.id == removeID }
                            } label: {
                                Label("Remove", systemImage: "trash")
                            }
                            .buttonStyle(.bordered)
                        }

                        // Name at event (only show after Event is selected)
                        let hasEvent = !identity.idReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        if hasEvent {
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

    private func newPerson() {
        let personID = identityStore.addPerson()
        selectedPersonID = personID
        loadDrafts(for: personID)
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

    private func deleteAdditionalDraft(at idx: Int) {
        guard draftAdditional.indices.contains(idx) else { return }
        let idToDelete = draftAdditional[idx].id
        identityStore.delete(id: idToDelete)

        if let pid = selectedPersonID {
            loadDrafts(for: pid)
        }
        refreshToken = UUID()
    }

    private func saveAllDrafts(for personID: String) {
        guard var birth = draftBirth else { return }

        // Force birth identity invariants
        birth.personID = personID
        birth.idReason = "Birth"
        if birth.idDate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            // If they provided a birthDate, mirror it into idDate as a nice default.
            if let bd = birth.birthDate?.trimmingCharacters(in: .whitespacesAndNewlines), !bd.isEmpty {
                birth.idDate = bd
            }
        }

        identityStore.upsert(birth)

        for v in draftAdditional {
            var copy = v
            copy.personID = personID
            identityStore.upsert(copy)
        }

        // Reload after store propagation (shortName/birthDate/favorite/notes sync)
        loadDrafts(for: personID)
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

    // MARK: - Binding helpers (Additional versions)

    private func bindingAdditional(_ idx: Int, _ keyPath: WritableKeyPath<DmpmsIdentity, String>) -> Binding<String> {
        Binding<String>(
            get: {
                guard draftAdditional.indices.contains(idx) else { return "" }
                return draftAdditional[idx][keyPath: keyPath]
            },
            set: { newValue in
                guard draftAdditional.indices.contains(idx) else { return }
                draftAdditional[idx][keyPath: keyPath] = newValue
            }
        )
    }

    private func optionalBindingAdditional(_ idx: Int, _ keyPath: WritableKeyPath<DmpmsIdentity, String?>) -> Binding<String> {
        Binding<String>(
            get: {
                guard draftAdditional.indices.contains(idx) else { return "" }
                return draftAdditional[idx][keyPath: keyPath] ?? ""
            },
            set: { newValue in
                guard draftAdditional.indices.contains(idx) else { return }
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                draftAdditional[idx][keyPath: keyPath] = trimmed.isEmpty ? nil : trimmed
            }
        )
    }
}

#Preview {
    DMPPPeopleManagerView()
}
