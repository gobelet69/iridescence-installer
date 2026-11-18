#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

APP_NAME="Iridescence Installer"
BUNDLE="${APP_NAME}.app"
BUILD_CONFIG="${1:-release}"
BUILD_STAGE="$(mktemp -d /tmp/IridescenceInstallerBuildStage.XXXXXX)"
BUILD_SCRATCH="$(mktemp -d /tmp/IridescenceInstallerScratch.XXXXXX)"
trap 'rm -rf "${BUILD_STAGE}" "${BUILD_SCRATCH}"' EXIT

echo "▸ Staging source files in /tmp to avoid iCloud coordination locks…"
mkdir -p "${BUILD_STAGE}"
cp -R Sources "${BUILD_STAGE}/"
if [ -d "Tests" ]; then
    cp -R Tests "${BUILD_STAGE}/"
fi
cp Package.swift "${BUILD_STAGE}/"

echo "▸ Building ${APP_NAME} (${BUILD_CONFIG})…"
cd "${BUILD_STAGE}"
UNIVERSAL="${UNIVERSAL:-0}"
if [ "$UNIVERSAL" = "1" ]; then
    for architecture in arm64 x86_64; do
        swift build -c "${BUILD_CONFIG}" --jobs 2 --triple "${architecture}-apple-macosx13.0" --scratch-path "${BUILD_SCRATCH}/${architecture}"
        binary_dir=$(swift build -c "${BUILD_CONFIG}" --triple "${architecture}-apple-macosx13.0" --scratch-path "${BUILD_SCRATCH}/${architecture}" --show-bin-path)
        cp "${binary_dir}/IridescenceInstaller" "${BUILD_STAGE}/IridescenceInstaller-${architecture}"
    done
    lipo -create "${BUILD_STAGE}/IridescenceInstaller-arm64" "${BUILD_STAGE}/IridescenceInstaller-x86_64" -output "${BUILD_STAGE}/IridescenceInstaller"
else
    swift build -c "${BUILD_CONFIG}" --jobs 2 --scratch-path "${BUILD_SCRATCH}/native"
    binary_dir=$(swift build -c "${BUILD_CONFIG}" --scratch-path "${BUILD_SCRATCH}/native" --show-bin-path)
    cp "${binary_dir}/IridescenceInstaller" "${BUILD_STAGE}/IridescenceInstaller"
fi

if [ "$BUILD_CONFIG" = "release" ]; then
    CONFIG_DIR="Release"
else
    CONFIG_DIR="Debug"
fi

BINARY="${BUILD_STAGE}/IridescenceInstaller"

cd - >/dev/null

echo "▸ Packaging ${BUNDLE} in /tmp staging…"
TMP_BUNDLE="${BUILD_STAGE}/${BUNDLE}"
rm -rf "${TMP_BUNDLE}" "${BUNDLE}"
mkdir -p "${TMP_BUNDLE}/Contents/MacOS"
mkdir -p "${TMP_BUNDLE}/Contents/Resources"

cp "${BINARY}" "${TMP_BUNDLE}/Contents/MacOS/Iridescence Installer"
chmod +x "${TMP_BUNDLE}/Contents/MacOS/Iridescence Installer"

if [ -d "Resources" ]; then
    cp -R Resources/* "${TMP_BUNDLE}/Contents/Resources/"
fi

cat > "${TMP_BUNDLE}/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>Iridescence Installer</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>org.111iridescence.installer</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Iridescence Installer</string>
    <key>CFBundleDisplayName</key>
    <string>Iridescence Installer</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.1</string>
    <key>CFBundleVersion</key>
    <string>2</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
PLIST

echo "▸ Sanitizing and ad-hoc codesigning ${TMP_BUNDLE}…"
xattr -cr "${TMP_BUNDLE}"
codesign --force --deep --sign - "${TMP_BUNDLE}"
codesign --verify --deep --strict "${TMP_BUNDLE}"

cp -R "${TMP_BUNDLE}" "${BUNDLE}"

echo "✔ Successfully built and verified ${BUNDLE}"
