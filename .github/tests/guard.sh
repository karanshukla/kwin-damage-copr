#!/usr/bin/env bash
# Runs the `run:` script of .github/workflows/guard.yml against a stub `gh`, so the checks it
# makes are tested exactly as they ship. Usage:
#   bash .github/tests/guard.sh
set -euo pipefail

root=$(cd "$(dirname "$0")/../.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

workflow="$root/.github/workflows/guard.yml"
if command -v yq >/dev/null; then
  yq -r '.jobs.guard.steps[0].run' "$workflow" >"$work/guard"
else
  python3 -c 'import sys, yaml; print(yaml.safe_load(open(sys.argv[1]))["jobs"]["guard"]["steps"][0]["run"])' \
    "$workflow" >"$work/guard"
fi

# The stub answers the one query guard makes: the changed-files list.
mkdir "$work/bin"
cat >"$work/bin/gh" <<'STUB'
#!/usr/bin/env bash
case "$*" in
  *@tsv*) cat "$STUB_DIR/files.tsv" ;;
  *) echo "unexpected gh call: $*" >&2; exit 2 ;;
esac
STUB
chmod +x "$work/bin/gh"

mkdir "$work/run"
failures=0
# expect <pass|fail> <name> <author>; files.tsv is written by the caller.
expect() {
  local want="$1" name="$2" author="$3" got
  if (cd "$work/run" && env PATH="$work/bin:$PATH" STUB_DIR="$work" \
    GITHUB_STEP_SUMMARY="$work/summary" REPO=o/r PR=1 AUTHOR="$author" OWNER=karanshukla \
    bash "$work/guard" >/dev/null 2>&1); then got=pass; else got=fail; fi
  if [ "$got" = "$want" ]; then
    echo "ok   $name"
  else
    echo "FAIL $name: wanted $want, got $got"
    failures=$((failures + 1))
  fi
}

files() { printf '%s\n' "$@" >"$work/files.tsv"; }

files $'0001-backends-drm-send-FB_DAMAGE_CLIPS-for-composited-frames.patch\tmodified\t'
expect pass "the owner may change the patch" karanshukla
expect fail "anyone else may not change the patch" someone
expect fail "dependabot may not change the patch unreviewed" 'dependabot[bot]'

files $'README.md\tmodified\t'
expect pass "anyone may change the README" someone

files $'TAG\tmodified\t'
expect fail "TAG is protected" someone

files $'make-srpm.sh\tmodified\t' $'README.md\tmodified\t'
expect fail "a protected file among unprotected ones is caught" someone

files $'.github/workflows/copr.yml\tmodified\t'
expect fail "workflows are protected" someone

files $'newfile.sh\tadded\t'
expect fail "a new file is protected by default" someone

files $'README.md\trenamed\tmake-srpm.sh'
expect fail "renaming a protected file is judged on its old path" someone

[ "$failures" -eq 0 ] || { echo "$failures guard case(s) failed" >&2; exit 1; }
