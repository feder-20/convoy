#!/bin/bash
# Prepara la entrega de Convoy: app firmada con hardened runtime, DMG y (si hay credenciales) notarización.
#
#   Desarrollo (sin cuenta de pago):      ./make-release.sh
#   Entrega real (Developer ID):          CONVOY_SIGN_ID="Developer ID Application: Tu Nombre (TEAMID)" \
#                                         CONVOY_NOTARY_PROFILE="convoy-notary" ./make-release.sh
#
# El perfil de notarización se crea una vez con:
#   xcrun notarytool store-credentials convoy-notary --apple-id TU_APPLE_ID --team-id TEAMID --password <contraseña de app>
set -euo pipefail
cd "$(dirname "$0")"
VERSION=$(cat VERSION)
SIGN_ID="${CONVOY_SIGN_ID:--}"
PROFILE="${CONVOY_NOTARY_PROFILE:-}"

./make-app.sh
APP=build/Convoy.app
DMG="build/Convoy-$VERSION.dmg"

STAGE=build/dmg
rm -rf "$STAGE" "$DMG"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
cp "$APP/Contents/Resources/AppIcon.icns" "$STAGE/.VolumeIcon.icns"
SetFile -a C "$STAGE" 2>/dev/null || true
hdiutil create -volname "Convoy" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
osascript -l JavaScript -e 'ObjC.import("AppKit"); function run(a){ var img=$.NSImage.alloc.initWithContentsOfFile($(a[1])); $.NSWorkspace.sharedWorkspace.setIconForFileOptions(img,$(a[0]),0); }' "$DMG" "$APP/Contents/Resources/AppIcon.icns" >/dev/null 2>&1 || true

if [ "$SIGN_ID" != "-" ]; then
  codesign --force --timestamp --sign "$SIGN_ID" "$DMG"
  if [ -n "$PROFILE" ]; then
    echo "Notarizando (puede tardar unos minutos)…"
    xcrun notarytool submit "$DMG" --keychain-profile "$PROFILE" --wait
    xcrun stapler staple "$DMG"
    xcrun stapler validate "$DMG"
    spctl --assess --type open --context context:primary-signature -v "$DMG"
    echo "Listo y notarizado: $DMG"
  else
    echo "Firmado con Developer ID, SIN notarizar (falta CONVOY_NOTARY_PROFILE): $DMG"
  fi
else
  echo "Listo (firma ad hoc, solo para pruebas; macOS pedirá clic derecho → Abrir): $DMG"
fi
cp "$DMG" build/Convoy.dmg   # nombre fijo para el enlace /releases/latest/download/Convoy.dmg
shasum -a 256 "$DMG"
