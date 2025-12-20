//
//  DmpmsPeopleSnapshot.swift
//  dMagy Picture Prep
//
//  Created by dmagy on 12/19/25.
//

import Foundation

// cp-2025-12-19-PS1(PEOPLE-SNAPSHOT-MODEL)

struct DmpmsPeopleSnapshot: Codable, Hashable, Identifiable {
    var id: String
    var createdAtISO8601: String
    var note: String
    var peopleV2: [DmpmsPersonInPhoto]

    init(
        id: String = UUID().uuidString,
        createdAtISO8601: String = ISO8601DateFormatter().string(from: Date()),
        note: String = "",
        peopleV2: [DmpmsPersonInPhoto]
    ) {
        self.id = id
        self.createdAtISO8601 = createdAtISO8601
        self.note = note
        self.peopleV2 = peopleV2
    }
}
