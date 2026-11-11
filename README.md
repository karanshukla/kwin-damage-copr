# kwin-damage-copr

Fedora's `kwin`, rebuilt with one patch: `0001-backends-drm-send-FB_DAMAGE_CLIPS-for-composited-frames.patch`.

Stock KWin sets `FB_DAMAGE_CLIPS` to 0 on every atomic commit, so the kernel treats every frame
as fully damaged and Intel's PSR2 / Panel Replay selective update refreshes the whole panel
every time. The patch fills the property from the damage KWin actually rendered, and falls back
to 0 whenever the damage isn't known (direct scanout, cursor and software layers, scaled or
transformed planes). The same change is proposed upstream as KWin MR !3548.

## Install

```
sudo dnf copr enable karanshukla/kwin-damage-copr
sudo dnf upgrade kwin kwin-common kwin-libs
```

Then log out and back in. Packages carry a `.fbdmgN` release suffix (`rpm -q kwin-libs`).
To go back to stock: `sudo dnf copr remove karanshukla/kwin-damage-copr && sudo dnf distro-sync kwin kwin-common kwin-libs`.

## How it updates

`.github/workflows/copr.yml` runs every 6 hours:

1. `stable-version.sh` asks Fedora's `fedora` + `updates` repos which kwin they serve now.
2. If COPR has no build of that version with this repo's `TAG` yet, `make-srpm.sh` downloads
   Fedora's source RPM, verifies its signature against the Fedora release key, checks the patch
   applies, adds it to the spec as `Patch900`, appends `.fbdmgN` to the release, and builds the
   SRPM.
3. `copr-cli` submits it to COPR and waits for the build.

A run fails, and GitHub emails, if the signature does not verify, the patch stops applying, or
the COPR build fails. A failed version is not retried on schedule; run the workflow by hand with
`retry`, or bump `TAG`.

When Fedora ships a new kwin, it can reach your machine a few hours before the patched build
does. The next `dnf upgrade` after the COPR build finishes puts the patch back. No repo priority
is set, so dnf never holds kwin back waiting for this repo.

To build the SRPM locally (on Fedora, or in `registry.fedoraproject.org/fedora:45`):

```
./make-srpm.sh "$(./stable-version.sh)" out
```

## Maintenance

- **Patch changed:** replace the `.patch`, bump `TAG` (`fbdmg1` → `fbdmg2`), push.
- **New Fedora release:** add it to the matrix in `copr.yml` and the chroot to the COPR project.
- **COPR token:** the `COPR_CONFIG` secret in the `copr` environment (main only) is the contents
  of `~/.config/copr` from <https://copr.fedorainfracloud.org/api/>. It expires after 180 days:
  `gh secret set COPR_CONFIG --env copr -R karanshukla/kwin-damage-copr`.
- **Upstream merge:** once KWin ships the change (MR !3548), stop the schedule and point users
  back at stock kwin.

See [SECURITY.md](SECURITY.md) for what is checked and what is trusted.

## License

GPL-2.0-or-later, the same as KWin, which the patch modifies. See [LICENSE](LICENSE).
