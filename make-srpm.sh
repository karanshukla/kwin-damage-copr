#!/bin/bash
# Build a source RPM of Fedora's kwin NVR with the damage patch added.
#
# Usage: ./make-srpm.sh kwin-6.8.2-3.fc45 OUTDIR
# Needs: curl rpm-build cpio patch xz python3. Run on the same Fedora release as the NVR, so
# %{dist} matches. Exits 3 if the patch no longer applies.

set -euo pipefail

NVR=$1
OUT=$(realpath -m "$2")
HERE=$(cd "$(dirname "$0")" && pwd)
PATCH=$(ls "$HERE"/0001-*.patch)
TAG=$(cat "$HERE/TAG")

VR=${NVR#kwin-}
VER=${VR%%-*}
REL=${VR#*-}
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

curl -fsSL -o "$WORK/kwin.src.rpm" \
    "https://kojipkgs.fedoraproject.org/packages/kwin/$VER/$REL/src/$NVR.src.rpm"
mkdir "$WORK/in" "$WORK/src"
( cd "$WORK/in" && rpm2cpio ../kwin.src.rpm | cpio -idm --quiet )
tar -xJf "$WORK/in/kwin-$VER.tar.xz" -C "$WORK/src" --strip-components=1

if ! patch -p1 --dry-run -d "$WORK/src" < "$PATCH" >/dev/null; then
    echo "::error::the patch does not apply to $NVR" >&2
    patch -p1 --dry-run -d "$WORK/src" < "$PATCH" | tail -20 >&2 || true
    exit 3
fi
grep -q '^%autosetup' "$WORK/in/kwin.spec" || { echo "::error::spec no longer uses %autosetup" >&2; exit 4; }

cp "$PATCH" "$WORK/in/"
python3 -I - "$WORK/in/kwin.spec" "$(basename "$PATCH")" "$TAG" <<'EOF'
import re, sys
path, patch, tag = sys.argv[1:4]
s = open(path).read()
s, n = re.subn(r'^(Release:\s*\S*?)(%\{\?dist\})', r'\1\2.' + tag, s, count=1, flags=re.M)
assert n == 1, "no Release line to tag"
s, n = re.subn(r'^(Source1:.*\n)', r'\1Patch900:  ' + patch + '\n', s, count=1, flags=re.M)
assert n == 1, "no Source1 line to hang the patch on"
open(path, 'w').write(s)
EOF
grep -nE '^(Release|Patch900):' "$WORK/in/kwin.spec"

mkdir -p "$OUT"
rpmbuild -bs "$WORK/in/kwin.spec" \
    --define "_sourcedir $WORK/in" --define "_srcrpmdir $OUT" --define "_topdir $WORK/rpmbuild"
ls "$OUT"/*.src.rpm
