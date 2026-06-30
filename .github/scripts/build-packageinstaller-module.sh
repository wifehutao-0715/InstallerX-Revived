#!/usr/bin/env bash
set -euo pipefail

: "${APK_PATH:?APK_PATH is required}"
: "${APP_ID:?APP_ID is required}"
: "${MODULE_VARIANT:?MODULE_VARIANT is required}"
: "${VERSION_TAG:?VERSION_TAG is required}"
: "${CHANNEL:?CHANNEL is required}"

MODULE_ROOT="module-output/${MODULE_VARIANT}"
MODULE_ZIP_NAME="${MODULE_VARIANT}-${VERSION_TAG}-online-${CHANNEL}.zip"
MODULE_ZIP_PATH="module-output/${MODULE_ZIP_NAME}"
VERSION_CODE="$(git rev-list --count HEAD)"

rm -rf "$MODULE_ROOT"
mkdir -p "$MODULE_ROOT/META-INF/com/google/android"
mkdir -p "$MODULE_ROOT/system/priv-app/PackageInstaller/lib"
mkdir -p "$MODULE_ROOT/system/priv-app/PackageInstaller/oat"

cp "$APK_PATH" "$MODULE_ROOT/system/priv-app/PackageInstaller/PackageInstaller.apk"

cat > "$MODULE_ROOT/module.prop" <<EOF
id=${APP_ID}
name=InstallerX Revived
version=${VERSION_TAG}
versionCode=${VERSION_CODE}
author=wxxsfxyzm
description=InstallerX as System Package Installer (${MODULE_VARIANT}, online ${CHANNEL})
EOF

cat > "$MODULE_ROOT/customize.sh" <<'EOF'
SKIPUNZIP=0

ui_print "- Installing PackageInstaller Replacement..."
ui_print "- Setting permissions..."
set_perm_recursive "$MODPATH/system" 0 0 0755 0644
EOF

cat > "$MODULE_ROOT/service.sh" <<'EOF'
#!/system/bin/sh
rm -rf /data/system/package_cache/*
rm "$0"
EOF

cat > "$MODULE_ROOT/uninstall.sh" <<'EOF'
#!/system/bin/sh
rm -rf /data/system/package_cache/*
EOF

cat > "$MODULE_ROOT/action.sh" <<EOF
#!/system/bin/sh
am start -n ${APP_ID}/com.rosan.installer.ui.activity.SettingsActivity
EOF

cat > "$MODULE_ROOT/META-INF/com/google/android/update-binary" <<'EOF'
#!/sbin/sh

umask 022

ui_print() { echo "$1"; }

require_new_magisk() {
  ui_print "*******************************"
  ui_print " Please install Magisk v20.4+! "
  ui_print "*******************************"
  exit 1
}

OUTFD=$2
ZIPFILE=$3

mount /data 2>/dev/null

[ -f /data/adb/magisk/util_functions.sh ] || require_new_magisk
. /data/adb/magisk/util_functions.sh
[ "$MAGISK_VER_CODE" -lt 20400 ] && require_new_magisk

install_module
exit 0
EOF

cat > "$MODULE_ROOT/META-INF/com/google/android/updater-script" <<'EOF'
#MAGISK
EOF

chmod 0755 "$MODULE_ROOT/action.sh" \
  "$MODULE_ROOT/customize.sh" \
  "$MODULE_ROOT/service.sh" \
  "$MODULE_ROOT/uninstall.sh" \
  "$MODULE_ROOT/META-INF/com/google/android/update-binary"
find "$MODULE_ROOT/system" -type d -exec chmod 0755 {} \;
find "$MODULE_ROOT/system" -type f -exec chmod 0644 {} \;

mkdir -p module-output
(cd "$MODULE_ROOT" && zip -r "../${MODULE_ZIP_NAME}" .)

if [ -n "${GITHUB_OUTPUT:-}" ]; then
  {
    echo "module_path=${MODULE_ZIP_PATH}"
    echo "module_name=${MODULE_ZIP_NAME}"
  } >> "$GITHUB_OUTPUT"
fi
