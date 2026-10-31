import Foundation

/// Robust representation of an application semantic version.
/// Handles standard SemVer, optional `v` prefixes, build metadata, and prerelease tags.
public struct AppVersion: Comparable, Hashable, Codable, Sendable, CustomStringConvertible {
    public let raw: String
    public let major: Int
    public let minor: Int
    public let patch: Int
    public let prerelease: String?
    public let build: String?

    public init(_ rawString: String) {
        self.raw = rawString.trimmingCharacters(in: .whitespacesAndNewlines)
        var cleaned = self.raw
        if cleaned.lowercased().hasPrefix("v") {
            cleaned.removeFirst()
        }

        // Split build metadata (+...)
        let buildParts = cleaned.split(separator: "+", maxSplits: 1, omittingEmptySubsequences: true)
        if buildParts.count > 1 {
            self.build = String(buildParts[1])
            cleaned = String(buildParts[0])
        } else {
            self.build = nil
        }

        // Split prerelease (-...)
        let preParts = cleaned.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: true)
        if preParts.count > 1 {
            self.prerelease = String(preParts[1])
            cleaned = String(preParts[0])
        } else {
            self.prerelease = nil
        }

        // Parse numerical components (major.minor.patch)
        let numParts = cleaned.split(separator: ".").compactMap { Int($0) }
        self.major = numParts.indices.contains(0) ? numParts[0] : 0
        self.minor = numParts.indices.contains(1) ? numParts[1] : 0
        self.patch = numParts.indices.contains(2) ? numParts[2] : 0
    }

    public init(major: Int, minor: Int, patch: Int, prerelease: String? = nil, build: String? = nil) {
        self.major = major
        self.minor = minor
        self.patch = patch
        self.prerelease = prerelease
        self.build = build
        var str = "\(major).\(minor).\(patch)"
        if let pre = prerelease {
            str += "-\(pre)"
        }
        if let b = build {
            str += "+\(b)"
        }
        self.raw = str
    }

    public var isPrerelease: Bool {
        return prerelease != nil
    }

    public var displayVersion: String {
        var str = "\(major).\(minor).\(patch)"
        if let pre = prerelease {
            str += "-\(pre)"
        }
        return str
    }

    public var description: String {
        return raw.isEmpty ? "\(major).\(minor).\(patch)" : raw
    }

    public static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        if lhs.major != rhs.major {
            return lhs.major < rhs.major
        }
        if lhs.minor != rhs.minor {
            return lhs.minor < rhs.minor
        }
        if lhs.patch != rhs.patch {
            return lhs.patch < rhs.patch
        }

        // SemVer: A normal version has higher precedence than a prerelease version
        // e.g. 1.0.0-beta < 1.0.0
        switch (lhs.prerelease, rhs.prerelease) {
        case (nil, nil):
            return false
        case (.some, nil):
            return true  // lhs is prerelease, rhs is release -> lhs < rhs
        case (nil, .some):
            return false // lhs is release, rhs is prerelease -> lhs > rhs
        case let (preL?, preR?):
            return comparePrereleases(preL, preR)
        }
    }

    public static func == (lhs: AppVersion, rhs: AppVersion) -> Bool {
        return lhs.major == rhs.major &&
               lhs.minor == rhs.minor &&
               lhs.patch == rhs.patch &&
               lhs.prerelease == rhs.prerelease
    }

    private static func comparePrereleases(_ preL: String, _ preR: String) -> Bool {
        let segL = preL.split(separator: ".")
        let segR = preR.split(separator: ".")
        let count = min(segL.count, segR.count)

        for i in 0..<count {
            let partL = segL[i]
            let partR = segR[i]

            let intL = Int(partL)
            let intR = Int(partR)

            if let il = intL, let ir = intR {
                if il != ir { return il < ir }
            } else if intL != nil && intR == nil {
                // Numeric identifiers always have lower precedence than non-numeric identifiers
                return true
            } else if intL == nil && intR != nil {
                return false
            } else {
                let cmp = partL.compare(partR, options: .caseInsensitive)
                if cmp != .orderedSame {
                    return cmp == .orderedAscending
                }
            }
        }

        return segL.count < segR.count
    }
}
