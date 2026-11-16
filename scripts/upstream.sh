#!/bin/sh
# Helpers for the official Zoraxy releases (https://github.com/tobychui/zoraxy).
#
#   upstream.sh latest                       print the latest stable version (without "v")
#   upstream.sh fetch <version> <arch> <out>  download zoraxy_linux_<arch> of that release
#                                             (arch "windows_amd64": zoraxy_windows_amd64.exe)
#                                             and verify it against the SHA-256 digest
#                                             GitHub publishes for the asset
#
# Requires curl, python3 and sha256sum. Set GITHUB_TOKEN to avoid API rate limits.
set -eu

REPO=${UPSTREAM_REPO:-tobychui/zoraxy}
API=https://api.github.com/repos/$REPO

api() {
    if [ -n "${GITHUB_TOKEN:-}" ]; then
        curl -fsSL -H "Authorization: Bearer $GITHUB_TOKEN" "$1"
    else
        curl -fsSL "$1"
    fi
}

case "${1:-}" in
latest)
    api "$API/releases/latest" | python3 -c 'import json,sys; print(json.load(sys.stdin)["tag_name"].lstrip("v"))'
    ;;
fetch)
    [ $# -eq 4 ] || { echo "usage: $0 fetch <version> <arch> <out>" >&2; exit 2; }
    version=${2#v} out=$4
    case "$3" in
    windows_*) asset=zoraxy_$3.exe ;;
    *) asset=zoraxy_linux_$3 ;;
    esac
    digest=$(api "$API/releases/tags/v$version" | python3 -c '
import json, sys
name = sys.argv[1]
for a in json.load(sys.stdin)["assets"]:
    if a["name"] == name:
        print((a.get("digest") or "").split(":", 1)[-1])
        break
else:
    sys.exit("asset %s not found in release" % name)
' "$asset")
    [ -n "$digest" ] || { echo "no SHA-256 digest published for $asset" >&2; exit 1; }
    mkdir -p "$(dirname "$out")"
    curl -fsSL --retry 3 -o "$out.part" "https://github.com/$REPO/releases/download/v$version/$asset"
    echo "$digest  $out.part" | sha256sum -c --quiet - || { rm -f "$out.part"; exit 1; }
    mv "$out.part" "$out"
    echo "$asset v$version: sha256 $digest verified"
    ;;
*)
    sed -n '2,11s/^# \{0,1\}//p' "$0" >&2
    exit 2
    ;;
esac
