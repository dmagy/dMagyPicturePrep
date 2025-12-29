import Foundation

struct DMPPUserLocation: Codable, Hashable, Identifiable {

    var id: UUID = UUID()

    /// Short dropdown label: "Ashcroft", "Ames", "1st Lutheran"
    var shortName: String

    /// Longer description: "Our Family House", "Innovation Center"
    var description: String? = nil

    /// Address fields used to fill/compare
    var streetAddress: String? = nil
    var city: String? = nil
    var state: String? = nil
    var country: String? = nil

    /// Normalized key used for matching against reverse-geocoded results.
    var matchKey: String {
        [
            norm(streetAddress),
            norm(city),
            norm(state),
            norm(country)
        ]
        .joined(separator: "|")
    }

    private func norm(_ s: String?) -> String {
        (s ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
}
