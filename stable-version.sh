#!/bin/bash
# Print VERSION-RELEASE of the kwin that Fedora's stable repos (fedora + updates) serve right now.
#
# Asks the repos rather than Koji: a build is tagged in Koji hours before the updates repo is
# composed, and the source RPM is only downloadable from the repo once it is there.
# Run on the Fedora release you are building for.

set -euo pipefail

vr=$(dnf -q repoquery --refresh --disablerepo='*' --enablerepo=fedora --enablerepo=updates \
    --latest-limit=1 --qf '%{version}-%{release}\n' kwin.x86_64)
[[ $vr =~ ^[0-9][0-9.]*-[0-9][^[:space:]]*$ ]] || { echo "unexpected kwin version: '$vr'" >&2; exit 1; }
echo "$vr"
