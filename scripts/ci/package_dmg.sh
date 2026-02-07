#!/usr/bin/env bash
set -euo pipefail

APP_NAME="${APP_NAME:-quicker}"
VERSION="${VERSION:-}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-build/DerivedData}"
CONFIGURATION="${CONFIGURATION:-Release}"
OUT_DIR="${OUT_DIR:-build/artifacts}"

if [[ -z "${VERSION}" ]]; then
  if command -v git >/dev/null 2>&1 && git rev-parse --git-dir >/dev/null 2>&1; then
    VERSION="$(git describe --tags --always --dirty)"
  else
    VERSION="local"
  fi
fi

VERSION_SAFE="${VERSION//\//-}"

mkdir -p "${OUT_DIR}"

default_app_path="${DERIVED_DATA_PATH}/Build/Products/${CONFIGURATION}/${APP_NAME}.app"
app_path=""
if [[ -d "${default_app_path}" ]]; then
  app_path="${default_app_path}"
else
  app_path="$(find "${DERIVED_DATA_PATH}/Build/Products" -maxdepth 4 -type d -name "${APP_NAME}.app" -print -quit 2>/dev/null || true)"
fi

if [[ -z "${app_path}" || ! -d "${app_path}" ]]; then
  echo "error: cannot find ${APP_NAME}.app under ${DERIVED_DATA_PATH}" >&2
  echo "hint: run xcodebuild with -derivedDataPath ${DERIVED_DATA_PATH}" >&2
  exit 1
fi

staging_dir="build/dmg-staging/${APP_NAME}-${VERSION_SAFE}"
rm -rf "${staging_dir}"
mkdir -p "${staging_dir}"

ditto "${app_path}" "${staging_dir}/${APP_NAME}.app"
ln -s /Applications "${staging_dir}/Applications"

dmg_name="${APP_NAME}-${VERSION_SAFE}.dmg"
dmg_path="${OUT_DIR}/${dmg_name}"
rm -f "${dmg_path}"

hdiutil create \
  -volname "${APP_NAME}" \
  -srcfolder "${staging_dir}" \
  -ov \
  -format UDZO \
  "${dmg_path}"

(
  cd "${OUT_DIR}"
  shasum -a 256 "${dmg_name}" > "${dmg_name}.sha256"
  shasum -a 256 -c "${dmg_name}.sha256" >/dev/null
)

echo "Created:"
echo "  ${dmg_path}"
echo "  ${dmg_path}.sha256"

