#!/bin/sh
# Builds Wakeintosh.app. Pass --install to copy it to /Applications and relaunch.
set -e
cd "$(dirname "$0")"

APP="Wakeintosh.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

VERSION="${VERSION:-1.0}"

# Universal binary: Apple Silicon + Intel.
BUILD="$(mktemp -d)"
swiftc -O -target arm64-apple-macos13 main.swift -o "$BUILD/arm64"
swiftc -O -target x86_64-apple-macos13 main.swift -o "$BUILD/x86_64"
lipo -create "$BUILD/arm64" "$BUILD/x86_64" -output "$APP/Contents/MacOS/Wakeintosh"

# App icon from the rendered 1024px artwork.
[ -f assets/icon_1024.png ] || swift assets/make_art.swift assets
ICONSET="$(mktemp -d)/AppIcon.iconset"
mkdir -p "$ICONSET"
for s in 16 32 128 256 512; do
    sips -z $s $s assets/icon_1024.png --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
    sips -z $((s*2)) $((s*2)) assets/icon_1024.png --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Wakeintosh</string>
    <key>CFBundleDisplayName</key><string>Wakeintosh</string>
    <key>CFBundleIdentifier</key><string>work.mando.wakeintosh</string>
    <key>CFBundleExecutable</key><string>Wakeintosh</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleVersion</key><string>$VERSION</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
</dict>
</plist>
EOF

codesign --force --sign - "$APP"
echo "Built $APP"

if [ "$1" = "--install" ]; then
    pkill -x Wakeintosh || true
    rm -rf "/Applications/$APP"
    mv "$APP" /Applications/
    open "/Applications/$APP"
    echo "Installed to /Applications"
fi
