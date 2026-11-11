#!/bin/bash
# Compila Convoy y arma build/Convoy.app (firma ad hoc; para desarrollo).
set -euo pipefail
cd "$(dirname "$0")"
VERSION=$(cat VERSION)

swift build -c release --arch arm64 --arch x86_64
BIN=$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)

APP=build/Convoy.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN/Convoy" "$APP/Contents/MacOS/Convoy"

# Ícono de la app (.icns desde el PNG de 1024 del kit de marca).
ICONSET=$(mktemp -d)/AppIcon.iconset
mkdir -p "$ICONSET"
SRC=marca/convoy-icono-app-negro-1024.png
for s in 16 32 128 256 512; do
  sips -z $s $s "$SRC" --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
  sips -z $((s*2)) $((s*2)) "$SRC" --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
cp marca/convoy-barra-menu-template@2x.png "$APP/Contents/Resources/MenuBarIcon.png"
cp marca/convoy-simbolo-negro-transparente-512.png "$APP/Contents/Resources/Symbol.png"
cp marca/convoy-logo-negro-transparente-1540.png "$APP/Contents/Resources/Logo.png"
cp -R Resources/BuiltInTemplates "$APP/Contents/Resources/"

for lang in Resources/*.lproj; do [ -d "$lang" ] && cp -R "$lang" "$APP/Contents/Resources/"; done

# Acción rápida del Finder («Nuevo proyecto con Convoy»). Se regenera con QuickAction/make-workflow.py.
WF="QuickAction/Nuevo proyecto con Convoy.workflow"
if [ ! -d "$WF" ]; then echo "Falta $WF (python3 QuickAction/make-workflow.py)"; exit 1; fi
cp -R "$WF" "$APP/Contents/Resources/"

cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>Convoy</string>
  <key>CFBundleDisplayName</key><string>Convoy</string>
  <key>CFBundleIdentifier</key><string>com.chocolitossoft.convoy</string>
  <key>CFBundleExecutable</key><string>Convoy</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>CFBundleDevelopmentRegion</key><string>es</string>
  <key>CFBundleLocalizations</key><array><string>es</string><string>en</string></array>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>CFBundleURLTypes</key><array><dict>
    <key>CFBundleURLName</key><string>com.chocolitossoft.convoy</string>
    <key>CFBundleURLSchemes</key><array><string>convoy</string></array>
  </dict></array>
  <key>UTExportedTypeDeclarations</key><array><dict>
    <key>UTTypeIdentifier</key><string>co.convoy.template</string>
    <key>UTTypeDescription</key><string>Plantilla de Convoy</string>
    <key>UTTypeConformsTo</key><array><string>public.json</string></array>
    <key>UTTypeTagSpecification</key><dict><key>public.filename-extension</key><array><string>convoy</string></array></dict>
  </dict></array>
  <key>CFBundleDocumentTypes</key><array><dict>
    <key>CFBundleTypeName</key><string>Plantilla de Convoy</string>
    <key>CFBundleTypeRole</key><string>Editor</string>
    <key>LSItemContentTypes</key><array><string>co.convoy.template</string></array>
  </dict></array>
  <key>NSDesktopFolderUsageDescription</key><string>Convoy necesita acceder al Escritorio para crear carpetas de proyecto donde tú elijas.</string>
  <key>NSDocumentsFolderUsageDescription</key><string>Convoy necesita acceder a Documentos para crear carpetas de proyecto donde tú elijas.</string>
  <key>NSDownloadsFolderUsageDescription</key><string>Convoy necesita acceder a Descargas para crear carpetas de proyecto donde tú elijas.</string>
  <key>NSHumanReadableCopyright</key><string>© 2026 ChocolitosSoft</string>
</dict></plist>
EOF

# Firma: por defecto ad hoc (desarrollo). Con CONVOY_SIGN_ID="Developer ID Application: …" queda lista para notarizar.
SIGN_ID="${CONVOY_SIGN_ID:--}"
SIGN_ARGS=(--force --options runtime --entitlements Distribution/Convoy.entitlements --sign "$SIGN_ID")
[ "$SIGN_ID" != "-" ] && SIGN_ARGS+=(--timestamp)
codesign "${SIGN_ARGS[@]}" "$APP"
codesign --verify --strict --verbose=2 "$APP"
echo "Listo: $APP (v$VERSION)"
