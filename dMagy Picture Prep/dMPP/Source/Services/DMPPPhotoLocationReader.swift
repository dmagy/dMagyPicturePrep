//
//  DMPPPhotoLocationReader.swift
//  dMagy Picture Prep
//
//  cp-2025-12-26-LOC(READER-MKRG-1)
//

import Foundation
import CoreLocation
import ImageIO
import MapKit

enum DMPPPhotoLocationReader {

    // MARK: - GPS read (from file metadata)

    static func readGPS(from fileURL: URL) -> DmpmsGPS? {
        guard
            let src = CGImageSourceCreateWithURL(fileURL as CFURL, nil),
            let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [String: Any],
            let gps = props[kCGImagePropertyGPSDictionary as String] as? [String: Any]
        else {
            return nil
        }

        func double(_ key: CFString) -> Double? {
            let k = key as String
            if let n = gps[k] as? NSNumber { return n.doubleValue }
            if let d = gps[k] as? Double { return d }
            if let s = gps[k] as? String { return Double(s) }
            return nil
        }

        func string(_ key: CFString) -> String? {
            let k = key as String
            if let s = gps[k] as? String { return s }
            return nil
        }

        guard
            let latRaw = double(kCGImagePropertyGPSLatitude),
            let lonRaw = double(kCGImagePropertyGPSLongitude)
        else {
            return nil
        }

        let latRef = (string(kCGImagePropertyGPSLatitudeRef) ?? "N").uppercased()
        let lonRef = (string(kCGImagePropertyGPSLongitudeRef) ?? "E").uppercased()

        let lat = (latRef == "S") ? -abs(latRaw) : abs(latRaw)
        let lon = (lonRef == "W") ? -abs(lonRaw) : abs(lonRaw)

        let alt = double(kCGImagePropertyGPSAltitude)

        return DmpmsGPS(latitude: lat, longitude: lon, altitudeMeters: alt)
    }

    // MARK: - Reverse geocode (Tahoe-friendly MapKit)

    static func reverseGeocode(_ gps: DmpmsGPS) async -> DmpmsLocation? {
        let loc = CLLocation(latitude: gps.latitude, longitude: gps.longitude)

        // Note: MKReverseGeocodingRequest(location:) is failable on macOS 26.
        guard let request = MKReverseGeocodingRequest(location: loc) else {
            return nil
        }

        let items: [MKMapItem]? = await withCheckedContinuation { cont in
            request.getMapItems { items, _ in
                cont.resume(returning: items)
            }
        }

        guard let item = items?.first else { return nil }

        // Tahoe: placemark is deprecated; prefer addressRepresentations / address.
        let full = item.addressRepresentations?.fullAddress?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        let short = item.addressRepresentations?.shortAddress?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)

        let location = parseAddress(fullAddress: full, shortAddress: short)
        return location
    }

    // MARK: - Best-effort address parsing

    private static func parseAddress(fullAddress: String?, shortAddress: String?) -> DmpmsLocation? {

        // Prefer fullAddress; shortAddress is sometimes “City, State” only.
        guard let text = (fullAddress?.isEmpty == false ? fullAddress : shortAddress),
              !text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty
        else {
            return nil
        }

        // Common Apple formatted address is multi-line:
        // 1) street
        // 2) city, state zip
        // 3) country
        let lines = text
            .split(separator: "\n")
            .map { String($0).trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var street: String? = nil
        var city: String? = nil
        var state: String? = nil
        var country: String? = nil

        if lines.count >= 1 { street = lines[0] }

        if lines.count >= 2 {
            // Try “City, ST 80501”
            let line2 = lines[1]
            if let comma = line2.firstIndex(of: ",") {
                let left = String(line2[..<comma]).trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                let right = String(line2[line2.index(after: comma)...]).trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)

                city = left.isEmpty ? nil : left

                // State is usually first token of right side
                let tokens = right.split(separator: " ").map(String.init)
                if let first = tokens.first, !first.isEmpty {
                    state = first
                }
            } else {
                // No comma; leave it as “city-ish” fallback
                city = line2.isEmpty ? nil : line2
            }
        }

        if lines.count >= 3 {
            country = lines.last
        }

        // If “fullAddress” is actually “City, State” only, street is wrong.
        // If street has no digits and we only have 2 lines, assume it's not a street.
        if lines.count == 2,
           let s = street,
           s.rangeOfCharacter(from: CharacterSet.decimalDigits) == nil {
            // shift: treat line1 as city/state-ish, clear street
            street = nil
        }

        return DmpmsLocation(
            streetAddress: street,
            city: city,
            state: state,
            country: country
        )
    }
}
