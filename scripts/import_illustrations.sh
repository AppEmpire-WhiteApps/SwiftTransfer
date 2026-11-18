#!/bin/bash
# Imports generated PNG illustrations into Assets.xcassets/Illustrations and builds the app icon.
# Usage: scripts/import_illustrations.sh <source-dir-with-png>
set -euo pipefail

SRC="${1:?source directory}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ASSETS="${ROOT}/SwiftTransfer/Assets.xcassets"
DEST="${ASSETS}/Illustrations"

mkdir -p "${DEST}"
cat > "${DEST}/Contents.json" <<'JSON'
{
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
JSON

for file in "${SRC}"/*.png; do
    name="$(basename "${file}" .png)"
    if [[ "${name}" == "app_icon" ]]; then
        continue
    fi
    case "${name}" in
        ic3d_* | method_* | device_* | assistant_avatar | app_logo)
            width=420
            ;;
        *)
            width=900
            ;;
    esac
    set_dir="${DEST}/${name}.imageset"
    mkdir -p "${set_dir}"
    sips --resampleWidth "${width}" "${file}" --out "${set_dir}/${name}.png" > /dev/null
    cat > "${set_dir}/Contents.json" <<JSON
{
  "images" : [
    {
      "filename" : "${name}.png",
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
JSON
done

if [[ -f "${SRC}/app_icon.png" ]]; then
    ICON_DIR="${ASSETS}/AppIcon.appiconset"
    sips -s format png --resampleHeightWidth 1024 1024 "${SRC}/app_icon.png" --out "${ICON_DIR}/AppIcon.png" > /dev/null
    cat > "${ICON_DIR}/Contents.json" <<'JSON'
{
  "images" : [
    {
      "filename" : "AppIcon.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
JSON
fi

du -sh "${DEST}"
ls "${DEST}" | wc -l
