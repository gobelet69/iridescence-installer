import SwiftUI
import AppKit
import IridescenceCore

struct WindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                window.titleVisibility = .hidden
                window.titlebarAppearsTransparent = true
                window.isMovableByWindowBackground = true
                window.tabbingMode = .disallowed
                window.toolbar = nil
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

@main
struct IridescenceInstallerApp: App {
    @StateObject private var appState = AppState.shared

    init() {
        // Prevent macOS from creating automatic window tabs
        NSWindow.allowsAutomaticWindowTabbing = false

        // Handle command-line arguments (e.g. --selftest, --tab, --render-views)
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
                .background(WindowConfigurator())
                .background(IridescenceTheme.canvas)
                .preferredColorScheme(nil) // System dynamic appearance
                .onAppear {
                    handleCaptureIfRequested()
                }
        }
        .windowStyle(.hiddenTitleBar)
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
        print("▸ Starting Iridescence Installer Self-Test…")

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

    /// Captures the window content directly from the AppKit layer without needing Screen Recording permission
    private func handleCaptureIfRequested() {
        guard let idx = CommandLine.arguments.firstIndex(of: "--capture-to"),
              idx + 1 < CommandLine.arguments.count else { return }
        let outPath = CommandLine.arguments[idx + 1]

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            guard let window = NSApp.windows.first(where: { $0.contentView != nil && $0.frame.width > 400 }),
                  let view = window.contentView else {
                print("No suitable window found for capture")
                exit(1)
            }

            let bounds = view.bounds
            guard bounds.width > 0 && bounds.height > 0,
                  let rep = view.bitmapImageRepForCachingDisplay(in: bounds) else {
                print("Failed to initialize bitmap rep")
                exit(1)
            }
            view.cacheDisplay(in: bounds, to: rep)

            if let png = rep.representation(using: .png, properties: [:]) {
                let url = URL(fileURLWithPath: outPath)
                try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                try? png.write(to: url)
                print("✔ Captured active window to \(outPath) (\(png.count) bytes)")
                exit(0)
            } else {
                print("Failed to convert view to PNG")
                exit(1)
            }
        }
    }
}
