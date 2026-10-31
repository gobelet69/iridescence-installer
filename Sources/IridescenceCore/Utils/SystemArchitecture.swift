import Foundation

public enum BinaryArchitecture: String, Codable, Sendable, CaseIterable {
    case arm64
    case x86_64
    case universal
    case unknown

    public var displayName: String {
        switch self {
        case .arm64: return "Apple Silicon"
        case .x86_64: return "Intel"
        case .universal: return "Universal"
        case .unknown: return "Unknown"
        }
    }

    /// Current machine hardware architecture
    public static var current: BinaryArchitecture {
        #if arch(arm64)
        return .arm64
        #elseif arch(x86_64)
        return .x86_64
        #else
        return .unknown
        #endif
    }

    /// Checks if this binary architecture is compatible with the host machine
    public func isCompatible(with host: BinaryArchitecture = .current) -> Bool {
        if self == .universal { return true }
        if self == host { return true }
        // On Apple Silicon (arm64), Rosetta 2 can run x86_64, but native arm64 is preferred.
        if host == .arm64 && self == .x86_64 { return true }
        return false
    }

    /// Infer architecture from an asset filename
    public static func infer(from filename: String) -> BinaryArchitecture {
        let lower = filename.lowercased()
        if lower.contains("universal") {
            return .universal
        } else if lower.contains("arm64") || lower.contains("aarch64") || lower.contains("apple-silicon") || lower.contains("m1") {
            return .arm64
        } else if lower.contains("x86_64") || lower.contains("x64") || lower.contains("intel") || lower.contains("amd64") {
            return .x86_64
        }
        return .unknown
    }

    /// Inspect a Mach-O executable file using `lipo -info`
    public static func inspectMachO(at executableURL: URL) -> BinaryArchitecture {
        guard FileManager.default.fileExists(atPath: executableURL.path) else {
            return .unknown
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/lipo")
        process.arguments = ["-info", executableURL.path]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8)?.lowercased() {
                let hasArm64 = output.contains("arm64")
                let hasX86 = output.contains("x86_64")
                if hasArm64 && hasX86 {
                    return .universal
                } else if hasArm64 {
                    return .arm64
                } else if hasX86 {
                    return .x86_64
                }
            }
        } catch {
            return .unknown
        }
        return .unknown
    }
}
