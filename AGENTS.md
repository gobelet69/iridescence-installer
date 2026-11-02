# Iridescence Installer — Agent Instructions & Architectural Guidelines

## 1. Project Overview & Architecture

**Iridescence Installer** is the official macOS utility for installing, updating, and verifying applications in the 111iridescence ecosystem:
- **Language & Runtime**: Swift 6.0, SwiftUI, AppKit.
- **Key Modules**:
  - `Sources/IridescenceCore/`: GitHub Releases client, JSON release decoding, semantic version parsing, SHA-256 checksum verification, quarantine attribute management (`com.apple.quarantine`), atomic app bundle swap, rollback backups.
  - `Sources/IridescenceInstaller/`: Graphical user interface, ecosystem app catalog, installation progress, and self-updating mechanics.
- **Brand Identity**: Deep Violet (`#702EE4` Light / `#9478FF` Dark) and Luminous Cyan.

---

## 2. Invariants & Safety Rules

1. **Security & Integrity Safeguards**:
   - Every downloaded binary must be verified against its official GitHub release SHA-256 checksum before unpacking or installing.
   - Do not bypass integrity checks. If a checksum fails, immediately abort and alert the user.
2. **Quarantine Handling**:
   - Quarantine management must strictly respect user explicit authorization; do not perform silent system-wide quarantine bypasses.
3. **Rollback Safety**:
   - Before replacing an existing application in `/Applications`, create an atomic backup so that failed updates can be rolled back safely without data loss.
4. **iCloud Build Invariant**:
   - Always run tests and builds with a `/tmp` scratch path:
     ```bash
     swift test --scratch-path /tmp/installer-test
     ```

---

## 3. Verification Commands

Before submitting or committing changes:
```bash
# 1. Run unit tests (12 tests)
swift test --scratch-path /tmp/installer-test

# 2. Build release bundle
./build.sh release
```

---

## 4. Standards Reference

Refer to the shared DevKit standards in `../111iridescence-devkit/standards/`:
- `swift-macos.md`: Strict concurrency, Swift PM `/tmp` builds, codesign detritus avoidance.
- `release.md`: Checksum verification, human approval gates.
- `privacy.md`: No logging of personal directories or private keys.
