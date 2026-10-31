#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

APP_NAME="Iridescence Installer"
BUNDLE="${APP_NAME}.app"
BUILD_CONFIG="${1:-release}"
BUILD_STAGE="/tmp/IridescenceInstallerBuildStage"

echo "▸ Staging source files in /tmp to avoid iCloud coordination locks…"
rm -rf "${BUILD_STAGE}"
mkdir -p "${BUILD_STAGE}"
cp -R Sources "${BUILD_STAGE}/"
if [ -d "Tests" ]; then
    cp -R Tests "${BUILD_STAGE}/"
fi
cp Package.swift "${BUILD_STAGE}/"

echo "▸ Building ${APP_NAME} (${BUILD_CONFIG})…"
cd "${BUILD_STAGE}"
swift build -c "${BUILD_CONFIG}" --scratch-path "/tmp/IridescenceInstallerScratch"

if [ "$BUILD_CONFIG" = "release" ]; then
    CONFIG_DIR="Release"
else
    CONFIG_DIR="Debug"
fi

BINARY="/tmp/IridescenceInstallerScratch/out/Products/${CONFIG_DIR}/IridescenceInstaller"

cd - >/dev/null

echo "▸ Packaging ${BUNDLE} in /tmp staging…"
TMP_BUNDLE="/tmp/${BUNDLE}"
rm -rf "${TMP_BUNDLE}" "${BUNDLE}"
mkdir -p "${TMP_BUNDLE}/Contents/MacOS"
mkdir -p "${TMP_BUNDLE}/Contents/Resources"

cp "${BINARY}" "${TMP_BUNDLE}/Contents/MacOS/Iridescence Installer"
chmod +x "${TMP_BUNDLE}/Contents/MacOS/Iridescence Installer"

if [ -f "Resources/AppIcon.icns" ]; then
    cp "Resources/AppIcon.icns" "${TMP_BUNDLE}/Contents/Resources/AppIcon.icns"
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
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
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
