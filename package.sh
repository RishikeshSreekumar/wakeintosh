#!/bin/sh
# Builds release artifacts (zip for Homebrew, dmg for manual install) and updates
# the cask's version + sha256.
# Usage: VERSION=1.0 ./package.sh
set -e
cd "$(dirname "$0")"

VERSION="${VERSION:-1.0}"
export VERSION
./build.sh

mkdir -p dist
ZIP="dist/Wakeintosh-$VERSION.zip"
DMG="dist/Wakeintosh-$VERSION.dmg"
rm -f "$ZIP" "$DMG"

# Zip (used by the Homebrew cask).
ditto -c -k --keepParent Wakeintosh.app "$ZIP"

# DMG with a drag-to-Applications layout.
STAGE="$(mktemp -d)/Wakeintosh"
mkdir -p "$STAGE"
cp -R Wakeintosh.app "$STAGE/"
ln -s /Applications "$STAGE/Applications"
cp Wakeintosh.app/Contents/Resources/AppIcon.icns "$STAGE/.VolumeIcon.icns"
if command -v SetFile >/dev/null; then SetFile -a C "$STAGE"; fi
hdiutil create -quiet -volname "Wakeintosh" -srcfolder "$STAGE" -fs HFS+ -format UDZO -ov "$DMG"

SHA=$(shasum -a 256 "$ZIP" | awk '{print $1}')
sed -i '' -e "s/^  version \".*\"/  version \"$VERSION\"/" -e "s/^  sha256 \".*\"/  sha256 \"$SHA\"/" Casks/wakeintosh.rb

echo "Packaged $ZIP"
echo "Packaged $DMG"
echo "zip sha256 $SHA"
