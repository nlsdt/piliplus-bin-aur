#!/usr/bin/env bash
set -euo pipefail

# Update PKGBUILD's pkgver/pkgrel/source_x86_64 from upstream GitHub Releases.
# This script is designed to run on generic Linux (e.g., GitHub ubuntu runners).

repo="bggRGjQaUbCoE/PiliPlus"
package_dir="${1:-.}"

pkgb="${package_dir%/}/PKGBUILD"
if [[ ! -f "$pkgb" ]]; then
  echo "PKGBUILD not found: $pkgb" >&2
  exit 1
fi

require() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1" >&2
    exit 1
  }
}

require curl
require jq
require sed

api_url="https://api.github.com/repos/${repo}/releases/latest"
release_json="$(curl -fsSL "$api_url")"

tag="$(jq -r '.tag_name // empty' <<<"$release_json")"
if [[ -z "$tag" || "$tag" == "null" ]]; then
  echo "Failed to read tag_name from GitHub API" >&2
  exit 1
fi

pkgver="${tag#v}"

asset_url="$(jq -r '.assets[]? | select(.name | test("^PiliPlus_linux_.*_amd64\\.tar\\.gz$")) | .browser_download_url' <<<"$release_json" | head -n 1)"

if [[ -z "$asset_url" ]]; then
  echo "Failed to find amd64 tar.gz asset in latest release." >&2
  echo "Looked for name matching: PiliPlus_linux_*_amd64.tar.gz" >&2
  exit 1
fi

echo "Upstream latest tag: $tag"
echo "Using asset: $asset_url"

# Update PKGBUILD fields.
# - reset pkgrel to 1 on new upstream versions
# - source_x86_64 is updated to the selected asset URL
sed -i -E \
  -e "s/^pkgver=.*/pkgver=${pkgver}/" \
  -e "s/^pkgrel=.*/pkgrel=1/" \
  "$pkgb"

sed -i -E \
  -e "s|\"https://github.com/bggRGjQaUbCoE/PiliPlus/releases/download/[^\"]+\"|\"${asset_url}\"|" \
  "$pkgb"

