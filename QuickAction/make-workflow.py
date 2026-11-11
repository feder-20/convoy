#!/usr/bin/env python3
"""Genera «Nuevo proyecto con Convoy.workflow»: Acción rápida del Finder para carpetas.
Abre convoy://new?path=<carpeta> (la app fija ese destino y pone el foco en el nombre del proyecto)."""
import plistlib, os, shutil, uuid

here = os.path.dirname(os.path.abspath(__file__))
out = os.path.join(here, "Nuevo proyecto con Convoy.workflow", "Contents")
shutil.rmtree(os.path.dirname(out), ignore_errors=True)
os.makedirs(out)

doc = plistlib.load(open(os.path.join(here, "template.wflow"), "rb"))
action = doc["actions"][0]["action"]
action["ActionParameters"] = {
    "COMMAND_STRING": 'u=$(V="$1" osascript -l JavaScript -e \'ObjC.import("stdlib"); function run(){return encodeURIComponent($.getenv("V"))}\'); open "convoy://new?path=$u"',
    "CheckedForUserDefaultShell": True, "inputMethod": 1, "shell": "/bin/zsh", "source": "",
}
for key in ("InputUUID", "OutputUUID", "UUID"):
    action[key] = str(uuid.uuid4()).upper()
plistlib.dump(doc, open(os.path.join(out, "document.wflow"), "wb"))

info = {"NSServices": [{
    "NSBackgroundColorName": "background", "NSIconName": "NSActionTemplate",
    "NSMenuItem": {"default": "Nuevo proyecto con Convoy"}, "NSMessage": "runWorkflowAsService",
    "NSRequiredContext": {"NSApplicationIdentifier": "com.apple.finder"},
    "NSSendFileTypes": ["public.folder"],
}]}
plistlib.dump(info, open(os.path.join(out, "Info.plist"), "wb"))
print("Nuevo proyecto con Convoy.workflow generado")
