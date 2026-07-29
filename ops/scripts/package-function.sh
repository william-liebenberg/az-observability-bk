#!/usr/bin/env bash
set -euo pipefail

echo "Installing zip and unzip"
apt-get update && apt-get upgrade -y zip unzip
echo "done installing zip and unzip"

app_name="${APP_NAME:?APP_NAME is required}"
build_number="${BUILDKITE_BUILD_NUMBER:?BUILDKITE_BUILD_NUMBER is required}"
commit="${BUILDKITE_COMMIT:?BUILDKITE_COMMIT is required}"
package_dir="artifacts/package/${app_name}"
package="artifacts/${app_name}-${build_number}.zip"
checksum="${package}.sha256"
manifest="${package}.manifest"

command -v zip >/dev/null 2>&1 || {
  echo "zip is required to package the Function App" >&2
  exit 1
}
command -v unzip >/dev/null 2>&1 || {
  echo "unzip is required to verify the Function App package" >&2
  exit 1
}

rm -rf "$package_dir" "$package" "$checksum" "$manifest"
npm ci
npm run build

mkdir -p "$package_dir/dist"
cp host.json package.json package-lock.json "$package_dir/"
cp -R dist/src "$package_dir/dist/"
npm ci --omit=dev --prefix "$package_dir"

(cd "$package_dir" && zip -qr "../../../${package}" .)
unzip -Z1 "$package" | grep -qx "host.json"
sha256sum "$package" > "$checksum"

cat > "$manifest" <<EOF
artifact=${package}
commit=${commit}
build_number=${build_number}
sha256=$(sha256sum "$package" | cut -d ' ' -f 1)
EOF

unzip -l "$package"
