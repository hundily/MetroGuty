#!/bin/zsh
# Compila o MetroGuty (universal: Apple Silicon + Intel), monta MetroGuty.app
# (com ícone feito a partir do logo) e gera MetroGuty.dmg para distribuição.
set -euo pipefail
cd "$(dirname "$0")"

ARCHS=(--arch arm64 --arch x86_64)
swift build -c release "${ARCHS[@]}"

APP="build/MetroGuty.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/mp3"
cp "$(swift build -c release "${ARCHS[@]}" --show-bin-path)/MetroGuty" "$APP/Contents/MacOS/MetroGuty"
cp Resources/mp3/*.mp3 "$APP/Contents/Resources/mp3/"
cp Resources/logo.jpg "$APP/Contents/Resources/logo.jpg"

# Ícone: logo em um squircle arredondado (padrão de ícone do macOS).
ICONSET="build/AppIcon.iconset"
rm -rf "$ICONSET" && mkdir -p "$ICONSET"
swift scripts/make_icon.swift Resources/logo.jpg build/icon_1024.png
for s in 16 32 128 256 512; do
  sips -z $s $s build/icon_1024.png --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
  sips -z $((s*2)) $((s*2)) build/icon_1024.png --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>MetroGuty</string>
  <key>CFBundleDisplayName</key><string>MetroGuty</string>
  <key>CFBundleIdentifier</key><string>com.metronoguty.mac</string>
  <key>CFBundleExecutable</key><string>MetroGuty</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.music</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSHumanReadableCopyright</key><string>METROGUTY • Motor Rítmico de Precisão</string>
</dict>
</plist>
PLIST

codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || true
rm -rf build/AppIcon.iconset build/icon_1024.png
echo "Pronto: $(pwd)/$APP"

# DMG: app + atalho para Aplicativos (arrastar para instalar).
DMG="build/MetroGuty.dmg"
STAGE="build/dmg"
rm -rf "$STAGE" "$DMG"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "MetroGuty" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGE"
echo "DMG: $(pwd)/$DMG"
