# Iridescence Installer

> Native macOS application manager, GitHub release orchestrator, and scoped Gatekeeper quarantine installer for the **111iridescence** software atelier.

[![macOS](https://img.shields.io/badge/macOS-13.0%2B-blue?logo=apple)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5.9%20%2F%206.0-orange?logo=swift)](https://swift.org)
[![Universal Binary](https://img.shields.io/badge/Architecture-Apple%20Silicon%20%7C%20Intel-purple)]()
[![License](https://img.shields.io/badge/License-MIT-green)](LICENSE)

---

## Overview

**Iridescence Installer** solves the friction of distributing and maintaining native, focused macOS software without an Apple Developer ID membership. It is exclusively tailored for applications created within the **111iridescence** ecosystem.

In standard macOS workflows, running unsigned software requires a 10-step manual process: downloading archives, mounting disk images, dragging bundles, being blocked by Gatekeeper quarantine, opening System Settings, overriding security warnings, and cleaning temporary files. 

Iridescence Installer eliminates this friction through a lightweight, secure, and transparent native application:
1. **Installed Apps**: Exclusively detects and manages official 111iridescence applications installed in `/Applications` and `~/Applications`, displaying architecture, release channel, versioning, and Gatekeeper quarantine state.
2. **Updates & Batch Installation**: Checks GitHub releases with ETag conditional caching and rate-limit awareness. Features one-click **Update All** with progress tracking, release notes, and atomic bundle replacement.
3. **Discover**: An ecosystem catalogue powered by GitHub repository topics (`iridescence-app`, `iridescence-featured`, `iridescence-beta`) and canonical static manifests, enabling newly published tools to appear automatically without recompilation.
4. **Scoped Quarantine Handling**: Integrated native extended-attribute management (`com.apple.quarantine`) strictly scoped to verified `.app` bundles, eliminating repetitive Gatekeeper friction for trusted publishers without disabling system-wide Gatekeeper.
5. **Self-Update Engine**: Built-in autonomous self-update pipeline that checks `gobelet69/iridescence-installer`, verifies SHA-256 sums, safely replaces the host bundle in `/Applications`, and relaunches without user intervention.
6. **Rollback & Safety**: Automatic backup of existing working applications prior to upgrade, enabling one-click instant recovery.

---

## Visual Design — The Prismatic Atelier

Iridescence Installer is built strictly with **The Prismatic Atelier (v2.1.0)** native design tokens:
- **Studio Surfaces**: Luminous Pearl (`#FAF9FC`) in light mode; Deep Obsidian (`#110D17` / `#16101D`) in dark mode.
- **Mathematical Pixel Grid**: 8pt discrete coordinate grid with subtle illuminated points and signature 5-cell pixel cross stars (`cross-5`).
- **Spectral Accents**: Electric Blue (`#2266F2`), Deep Violet (`#702EE4`), Luminous Cyan (`#0CC0E8`), and Controlled Turquoise (`#12CCB8`).
- **Native Precision**: Standard AppKit/SwiftUI controls, SF Pro body typography, and SF Mono tabular figures for versions and commit telemetry.

---

## Architecture & Security Model

```
┌─────────────────────────────────────────────────────────────┐
│                Iridescence Installer (SwiftUI)              │
├─────────────────┬────────────────────┬──────────────────────┤
│    Installed    │      Updates       │       Discover       │
└────────┬────────┴─────────┬──────────┴──────────┬───────────┘
         │                  │                     │
┌────────▼──────────────────▼─────────────────────▼───────────┐
│                    IridescenceCore Framework                │
├───────────────────┬─────────────────────┬───────────────────┤
│ AppScanner        │ GitHubClient        │ CatalogDiscovery  │
│ (Ecosystem Apps)  │ (ETags & Releases)  │ (Topics & Seeds)  │
├───────────────────┼─────────────────────┼───────────────────┤
│ InstallationEngine│ QuarantineManager   │ SelfUpdateManager │
│ (DMG/Zip Sandbox) │ (POSIX xattr API)   │ (Atomic Swap)     │
└───────────────────┴─────────────────────┴───────────────────┘
```

### Unsigned Distribution & Gatekeeper Quarantine
Iridescence applications are distributed without Apple Developer ID signing or Apple notarization credentials.

To provide a seamless experience while preserving security boundaries:
- **No Global Bypass**: The installer never touches system-wide Gatekeeper settings (`spctl --master-disable` is never used).
- **Strict Bundle Scoping**: Quarantine removal is executed via direct Darwin POSIX APIs (`removexattr`, `XATTR_NOFOLLOW`) applied strictly within the validated `.app` bundle directory tree.
- **Symlink Protection**: Symlinks within bundles are never traversed outside bundle bounds.
- **Trust Policy**:
  - **Official Ecosystem Sources** (`gobelet69/*`): Automatic quarantine removal can be enabled via an explicit user preference (**Settings → Security & Quarantine**).
  - **Third-Party Sources**: Strictly require separate user approval per repository before any quarantine modification.
- **Integrity Verification**: Downloads are validated against `SHA256SUMS.txt` published with releases prior to unpacking.

---

## Supported Ecosystem Applications

| Application | Bundle Identifier | GitHub Repository | Status |
|---|---|---|---|
| **Iridescence PDF Reader** | `com.iridecence.pdfreader` | `gobelet69/iridecence-pdf-reader` | Available |
| **Mass Print** | `com.massprint.app` | `gobelet69/Mass-Print` | Available |
| **Mac Resource Guard** | `com.macresourceguard.app` | `gobelet69/mac-resource-guard` | Available |
| **QuickPad** | `org.111iridescence.quickpad` | `gobelet69/QuickPad` | Available |
| **Iridescence Installer** | `org.111iridescence.installer` | `gobelet69/iridescence-installer` | Host Application |

---

## Adding a New Official Application

To publish a new application to the Iridescence Discover catalogue without recompiling the Installer:

1. **Repository Configuration**:
   - Host under the official GitHub account (`gobelet69`).
   - Add the repository topic `iridescence-app`.
   - Optionally add `iridescence-featured` to feature it on the Discover hero card.
   - Optionally add `iridescence-beta` for experimental releases.

2. **Publish Release**:
   - Tag with semantic versioning (e.g. `v1.0.0`).
   - Attach installable assets: `<AppName>-<version>-arm64.dmg` or `<AppName>-<version>-universal.zip`.
   - Attach `SHA256SUMS.txt` with SHA-256 hashes for all binaries.

3. **Automatic Discovery**:
   - The Installer queries GitHub REST API periodically or upon clicking **Refresh**.
   - Compatible macOS assets are parsed and verified.
   - A system notification announces the newly available application.

---

## Building & Development

### Requirements
- macOS 13.0 or later (Tested on macOS 14, 15, and 27)
- Xcode 15+ / Swift 5.9+ toolchain

### Quick Build
```bash
# Clone repository
git clone https://github.com/gobelet69/iridescence-installer.git
cd iridescence-installer

# Build debug binary and run self-test
swift build --scratch-path /tmp/IridescenceInstallerScratch
swift run --scratch-path /tmp/IridescenceInstallerScratch IridescenceInstaller --selftest

# Package release .app bundle
./build.sh release

# Package distribution DMG with SHA256 checksums
./package_dmg.sh
```

### Running Automated Tests
```bash
swift test --scratch-path /tmp/IridescenceInstallerBuild
```

---

## Performance Profile

| Metric | Measured Value | Standard |
|---|---|---|
| **Cold Self-Test Boot** | **138 ms** | < 500 ms |
| **Ecosystem App Scan (/Applications)** | **< 180 ms** | < 1,000 ms |
| **Universal Binary Size** | **3.02 MB** | Minimal footprint |
| **Compressed Distribution DMG** | **1.45 MB** | Lightweight distribution |
| **Idle Memory Footprint** | **~28 MB** | Low resource usage |

---

## Transparency & Privacy

- **No Analytics / Telemetry**: No tracking, phone-home metrics, or remote analytics are collected.
- **GitHub API Only**: Network requests are limited strictly to official GitHub API endpoints (`api.github.com`) and GitHub Release asset downloads.
- **Identity Notice**: In accordance with the 111iridescence standard, no private developer names or file paths are exposed.
- **AI Disclosure**: Developed with human architectural direction and advanced agentic AI assistance.

---

## License

MIT License. Designed and maintained for the **111iridescence** ecosystem.

## Release 1.0.1

Readable supporting text and explicit status badges, native navigation shortcuts and accessible sidebar selection/counts. The release DMG contains a Universal 2 build for Apple Silicon and Intel on macOS 13 or later. Ad-hoc signed; not Apple-notarised. See [CHANGELOG.md](CHANGELOG.md).
