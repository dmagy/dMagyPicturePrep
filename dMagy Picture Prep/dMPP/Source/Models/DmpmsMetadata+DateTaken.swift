//
//  DmpmsMetadata+DateTaken.swift
//  dMagy Picture Prep
//
//  Created by dMagy on 12/18/25.
//

import Foundation

// cp-2025-12-18-09(META-DATE)

extension DmpmsMetadata {

    /// Converts metadata.dateTaken (string) into a Date? for computations.
    /// Uses the same loose parsing rules as dateRange (YYYY, YYYY-MM, YYYY-MM-DD, etc.)
    var dateTakenDate: Date? {
        LooseYMD.parse(self.dateTaken)
    }
}
