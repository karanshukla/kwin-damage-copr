#!/bin/bash
# Build a source RPM of Fedora's kwin VERSION-RELEASE with the damage patch added.
#
# Usage: ./make-srpm.sh VERSION-RELEASE OUTDIR
#   e.g. ./make-srpm.sh "$(./stable-version.sh)" out
#
# Run on the Fedora release you are building for, so %{dist} matches (the workflows use the
# registry.fedoraproject.org/fedora:NN container). Needs dnf, rpm-build, cpio, patch, xz.
#
# Exit codes: 2 Fedora's signature on the source RPM did not verify, 3 the patch no longer
# applies on top of Fedora's own patches, 4 the spec changed shape and the edit below needs updating.

set -euo pipefail

VR=$1
OUT=$(realpath -m "$2")
HERE=$(cd "$(dirname "$0")" && pwd)
PATCH=$(ls "$HERE"/0001-*.patch)
TAG=$(<"$HERE/TAG")
FEDORA=$(rpm -E %fedora)
KEY=/usr/share/pki/rpm-gpg/RPM-GPG-KEY-fedora-$FEDORA-primary

[[ $VR =~ ^[0-9][0-9.]*-[0-9][^/[:space:]]*$ ]] || { echo "bad VERSION-RELEASE: '$VR'" >&2; exit 1; }
[[ $TAG =~ ^fbdmg[0-9]+$ ]] || { echo "bad TAG: '$TAG'" >&2; exit 1; }
VER=${VR%%-*}
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# 1. Fedora's source RPM of exactly that build, from the source repos (dnf checks it against
#    the repo metadata's checksum).
dnf -q download --source "kwin-$VR" --destdir "$WORK" \
    --disablerepo='*' --enablerepo=fedora-source --enablerepo=updates-source
SRPM=$WORK/kwin-$VR.src.rpm

# 2. Fedora's signature, checked against this release's primary key alone, in a keyring of its
#    own, so no other key on the machine (COPR, third-party repos) can vouch for it.
KEYRING=$WORK/keyring
rpmkeys --dbpath "$KEYRING" --define '_keyring rpmdb' --import "$KEY"
if ! rpmkeys --dbpath "$KEYRING" --define '_keyring rpmdb' --define '_pkgverify_level all' -K "$SRPM"; then
    echo "::error::kwin-$VR.src.rpm is not signed by the Fedora $FEDORA key" >&2
    exit 2
fi

# 3. Unpack.
mkdir "$WORK/in"
( cd "$WORK/in" && rpm2cpio "$SRPM" | cpio -idm --quiet )

# 4. Spec: add the patch (a high number, so it cannot clash with Fedora's own) and a release tag
#    after %{?dist}, so the result sorts above Fedora's build of the same version.
grep -q '^%autosetup' "$WORK/in/kwin.spec" || { echo "::error::kwin.spec no longer uses %autosetup" >&2; exit 4; }
cp "$PATCH" "$WORK/in/"
if ! python3 -I - "$WORK/in/kwin.spec" "$(basename "$PATCH")" "$TAG" <<'EOF'
import re, sys
path, patch, tag = sys.argv[1:4]
s = open(path).read()
s, n = re.subn(r'^(Release:\s*\S*?)(%\{\?dist\})', r'\1\2.' + tag, s, count=1, flags=re.M)
if n != 1:
    sys.exit("no Release line ending in %{?dist}")
s, n = re.subn(r'^(Source1:.*\n)', r'\1Patch900:  ' + patch + '\n', s, count=1, flags=re.M)
if n != 1:
    sys.exit("no Source1 line to put the patch after")
open(path, 'w').write(s)
EOF
then
    echo "::error::kwin.spec changed shape; update the spec edit in make-srpm.sh" >&2
    exit 4
fi
grep -nE '^(Release|Patch900):' "$WORK/in/kwin.spec"

# 5. Does it apply? Run the spec's real %prep, so Fedora's own patches go in first and ours
#    goes on top of them, exactly as in COPR. A dry run against the pristine tarball would miss a
#    Fedora patch that touches the same files.
if ! rpmbuild -bp --nodeps "$WORK/in/kwin.spec" --define "_topdir $WORK/rpmbuild" \
        --define "_sourcedir $WORK/in" --define "_builddir $WORK/build" > "$WORK/prep.log" 2>&1; then
    echo "::error::the patch does not apply to kwin $VR (on top of Fedora's own patches)" >&2
    tail -25 "$WORK/prep.log" >&2
    exit 3
fi
grep -q "$(basename "$PATCH")" "$WORK/prep.log" || { echo "::error::%prep did not apply $(basename "$PATCH")" >&2; tail -25 "$WORK/prep.log" >&2; exit 3; }

# 6. The source RPM itself.
mkdir -p "$OUT"
rpmbuild -bs "$WORK/in/kwin.spec" --define "_topdir $WORK/rpmbuild" \
    --define "_sourcedir $WORK/in" --define "_srcrpmdir $OUT"
want=$OUT/kwin-$VR.$TAG.src.rpm
[[ -f $want ]] || { echo "::error::expected $want, got: $(ls "$OUT")" >&2; exit 1; }
echo "$want"
