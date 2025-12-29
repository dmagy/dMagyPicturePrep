import Foundation
import CoreLocation
import ImageIO

// cp-2025-12-26-LOC(READER-V3-CLGEOCODER)

enum DMPPPhotoLocationReader {

    // MARK: - GPS from image file (EXIF/GPS via ImageIO)

    static func readGPS(from fileURL: URL) -> DmpmsGPS? {
        guard let src = CGImageSourceCreateWithURL(fileURL as CFURL, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any],
              let gps = props[kCGImagePropertyGPSDictionary] as? [CFString: Any]
        else {
            return nil
        }

        // Required
        guard let latRaw = gps[kCGImagePropertyGPSLatitude] as? Double,
              let lonRaw = gps[kCGImagePropertyGPSLongitude] as? Double
        else {
            return nil
        }

        let latRef = (gps[kCGImagePropertyGPSLatitudeRef] as? String)?.uppercased()
        let lonRef = (gps[kCGImagePropertyGPSLongitudeRef] as? String)?.uppercased()

        let latitude  = (latRef == "S") ? -abs(latRaw) : abs(latRaw)
        let longitude = (lonRef == "W") ? -abs(lonRaw) : abs(lonRaw)

        // Optional altitude
        var altitudeMeters: Double? = nil
        if let alt = gps[kCGImagePropertyGPSAltitude] as? Double {
            let altRef = gps[kCGImagePropertyGPSAltitudeRef] as? Int ?? 0 // 1 => below sea level
            altitudeMeters = (altRef == 1) ? -abs(alt) : alt
        }

        return DmpmsGPS(latitude: latitude, longitude: longitude, altitudeMeters: altitudeMeters)
    }

    // MARK: - Reverse geocode to structured address pieces

    /// Returns structured parts for your dMPMS location fields.
    /// NOTE: CLGeocoder is deprecated in macOS 26; MapKit replacement still lacks structured parity.
    static func reverseGeocode(_ gps: DmpmsGPS) async -> DmpmsLocation? {
        let loc = CLLocation(latitude: gps.latitude, longitude: gps.longitude)

        do {
            let placemarks = try await CLGeocoder().reverseGeocodeLocation(loc)
            guard let pm = placemarks.first else { return nil }

            let street = composeStreetAddress(subThoroughfare: pm.subThoroughfare,
                                              thoroughfare: pm.thoroughfare)

            let city = pm.locality?.trimmedNonEmpty
            let state = pm.administrativeArea?.trimmedNonEmpty
            let country = pm.country?.trimmedNonEmpty

            // If we got nothing useful, return nil
            if street == nil && city == nil && state == nil && country == nil {
                return nil
            }

            return DmpmsLocation(
                streetAddress: street,
                city: city,
                state: state,
                country: country
            )
        } catch {
            // If geocoding fails (offline, no permission, etc.), just return nil.
            return nil
        }
    }

    private static func composeStreetAddress(subThoroughfare: String?, thoroughfare: String?) -> String? {
        let num = subThoroughfare?.trimmedNonEmpty
        let name = thoroughfare?.trimmedNonEmpty

        switch (num, name) {
        case (nil, nil): return nil
        case (let n?, nil): return n
        case (nil, let t?): return t
        case (let n?, let t?): return "\(n) \(t)"
        }
    }
}

private extension String {
    var trimmedNonEmpty: String? {
        let t = trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
}
