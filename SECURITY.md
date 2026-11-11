# Security

The packages built here replace KWin, which runs as your compositor and sees every frame and
keystroke in the session. Installing them means trusting this repo, its build, and COPR.

## Reporting

Use [private vulnerability reporting](https://github.com/karanshukla/kwin-damage-copr/security/advisories/new).
Do not open a public issue for anything exploitable. Bugs in KWin itself belong upstream.

## Threat model

| Threat | Defence |
|---|---|
| Tampered Fedora source RPM (mirror, CDN, MITM) | `make-srpm.sh` downloads from Fedora's source repos, where dnf checks the repo metadata checksum, then verifies the RPM signature against the release's primary Fedora key alone, in an empty keyring. Any other key, including COPR's or a third-party repo's, cannot vouch for it. A bad signature aborts the build. |
| Something other than the reviewed patch reaching the package | The only change to Fedora's spec is a release tag and one `Patch900` line naming the patch in this repo. CI builds the same SRPM on every PR and checks the patch is in it. |
| PR that changes the patch, the build, or CI | The `guard` check fails any PR from someone other than the owner that touches anything except `README.md`. It runs from main's copy (`pull_request_target`) and never executes PR code. Only the owner's ruleset bypass can merge a flagged PR. Because a PR could add its own workflow with a job named `guard`, the ruleset does not rely on that check alone: every PR also needs a code-owner (owner) approval, given after its last push and dismissed by a new one. |
| Leaked COPR token | The token lives in the `copr` environment, which only `main` can deploy to, so a PR or another branch cannot read it. It is written to disk with mode 600 only in the job that calls COPR, after the SRPM is built. It expires after 180 days. |
| Compromised action | Every action is pinned to a commit SHA, only GitHub-owned actions are allowed, actionlint is checked against a pinned sha256, Dependabot waits 7 days and nothing auto-merges. |
| History rewritten | Force pushes and deletion of `main` are blocked by ruleset. |

## What it does not defend against

- **Fedora or KDE shipping a malicious kwin.** This verifies you got what Fedora signed, not that it is safe.
- **COPR's build infrastructure.** COPR builds the SRPM in its own mock chroot and signs the result with this project's COPR key. dnf checks that key when you install.
- **The Fedora container image.** The signing key comes from `fedora-gpg-keys` in `registry.fedoraproject.org/fedora:NN`, pulled over TLS by tag, not by digest.
- **A compromised owner account.**
