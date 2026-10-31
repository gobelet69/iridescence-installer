import SwiftUI
import AppKit
import IridescenceCore

@main
struct IridescenceUpdaterApp: App {
    @StateObject private var appState = AppState.shared

    init() {
        // Handle command-line arguments (e.g. --selftest, --tab)
        if CommandLine.arguments.contains("--selftest") {
            runSelfTestAndExit()
        }

        if let tabIdx = CommandLine.arguments.firstIndex(of: "--tab"), tabIdx + 1 < CommandLine.arguments.count {
            let tabArg = CommandLine.arguments[tabIdx + 1].lowercased()
            switch tabArg {
            case "updates":
                appState.selectedTab = .updates
            case "discover":
                appState.selectedTab = .discover
            case "settings":
                appState.selectedTab = .settings
            default:
                appState.selectedTab = .installed
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            SidebarView(appState: appState)
                .background(IridescenceTheme.canvas)
                .preferredColorScheme(nil) // System dynamic appearance
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Check for Updates...") {
                    Task {
                        await appState.checkAllUpdates()
                    }
                }
                .keyboardShortcut("u", modifiers: .command)

                Button("Rescan Installed Apps") {
                    Task {
                        await appState.scanLocalApps()
                    }
                }
                .keyboardShortcut("r", modifiers: .command)
            }
        }
    }

    /// In-app self-test execution for verification without GUI automation
    private func runSelfTestAndExit() -> Never {
        print("▸ Starting Iridescence Updater Self-Test…")

        // 1. Semantic version test
        let v1 = AppVersion("v1.2.3")
        let v2 = AppVersion("1.3.0-beta.1")
        assert(v1 < v2, "Version comparison failed")
        print("PASS semantic versioning and prerelease parsing")

        // 2. Quarantine validation test
        let qm = QuarantineManager.shared
        assert(!qm.hasQuarantine(at: URL(fileURLWithPath: "/nonexistent")), "Quarantine existence false check failed")
        print("PASS quarantine attribute manager and API bindings")

        // 3. Trust policy test
        var policy = TrustPolicy()
        assert(!policy.autoQuarantineOfficial, "Initial trust default must be false")
        assert(!policy.isQuarantineRemovalAuthorized(for: "gobelet69/iridecence-pdf-reader"))
        policy.autoQuarantineOfficial = true
        assert(policy.isQuarantineRemovalAuthorized(for: "gobelet69/iridecence-pdf-reader"))
        assert(!policy.isQuarantineRemovalAuthorized(for: "untrusted/tool"))
        policy.approveSource("untrusted/tool")
        assert(policy.isQuarantineRemovalAuthorized(for: "untrusted/tool"))
        print("PASS source trust policy and repository authorization")

        // 4. Catalog seed test
        let seeds = CatalogApp.defaultSeeds
        assert(!seeds.isEmpty, "Default catalog seeds must not be empty")
        assert(seeds.contains { $0.bundleIdentifier == "com.iridecence.pdfreader" })
        assert(seeds.contains { $0.bundleIdentifier == "com.massprint.app" })
        assert(seeds.contains { $0.bundleIdentifier == "com.macresourceguard.app" })
        print("PASS ecosystem catalog seed integrity")

        // 5. Architecture compatibility test
        let hostArch = BinaryArchitecture.current
        assert(BinaryArchitecture.universal.isCompatible(with: hostArch))
        print("PASS architecture compatibility engine")

        print("✔ ALL SELF-TESTS PASSED SUCCESSFULLY")
        exit(0)
    }
}
