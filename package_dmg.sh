#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

APP_NAME="Iridescence Updater"
BUNDLE_ID="org.111iridescence.updater"
VERSION="1.0.0"
DMG_NAME="Iridescence-Updater-${VERSION}-arm64.dmg"
SRC_APP="${APP_NAME}.app"
STAGING_DIR="/tmp/IridescenceUpdater_DMG_Staging"
DIST_DIR="${SCRIPT_DIR}/dist"

echo "============================================================"
echo " Packaging Iridescence Updater for macOS (${DMG_NAME}) "
echo " 111iridescence Atelier "
echo "============================================================"

./build.sh release

echo "==> Preparing DMG staging directory..."
rm -rf "${STAGING_DIR}" "${DIST_DIR}"
mkdir -p "${STAGING_DIR}" "${DIST_DIR}"

echo "==> Copying ${SRC_APP} to staging..."
cp -R "${SRC_APP}" "${STAGING_DIR}/"

echo "==> Sanitizing extended attributes and code signing in staging..."
xattr -cr "${STAGING_DIR}/${SRC_APP}"
codesign --force --deep --sign - "${STAGING_DIR}/${SRC_APP}"
codesign --verify --deep --strict --verbose=2 "${STAGING_DIR}/${SRC_APP}"

echo "==> Creating /Applications symlink..."
ln -s /Applications "${STAGING_DIR}/Applications"

echo "==> Building read-only compressed DMG: ${DIST_DIR}/${DMG_NAME}..."
hdiutil create -volname "${APP_NAME}" \
               -srcfolder "${STAGING_DIR}" \
               -ov \
               -format UDZO \
               "${DIST_DIR}/${DMG_NAME}"

rm -rf "${STAGING_DIR}"

(cd "${DIST_DIR}" && shasum -a 256 "${DMG_NAME}" > SHA256SUMS.txt && cat SHA256SUMS.txt)

echo "============================================================"
echo " ✓ Successfully packaged: ${DIST_DIR}/${DMG_NAME}"
echo "============================================================"
