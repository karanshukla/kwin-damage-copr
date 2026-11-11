# CLAUDE.md

Builds Fedora's `kwin` with one patch in COPR (`karanshukla/kwin-damage-copr`). There is no
code beyond the build: `stable-version.sh` (which kwin Fedora stable serves), `make-srpm.sh`
(signed SRPM → patched SRPM) and the workflows. README.md explains the flow, SECURITY.md the
threat model; keep both in step with any change to what is verified or trusted.

- Run `bash .github/tests/guard.sh` after touching `guard.yml`; it tests the shipped script.
- Actions are pinned to commit SHAs with a version comment. Only GitHub-owned actions are
  allowed in this repo; anything else is fetched by URL and checked against a pinned sha256.
- Anything passed to a `run:` block from `${{ }}` goes through `env:`.
- A change to the patch needs a `TAG` bump, or COPR sees the version as already built.
