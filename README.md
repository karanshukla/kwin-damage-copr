# kwin-damage-copr

Fedora's `kwin`, rebuilt with one patch: `0001-backends-drm-send-FB_DAMAGE_CLIPS-for-composited-frames.patch`.

Stock KWin sets `FB_DAMAGE_CLIPS` to 0 on every atomic commit, so the kernel treats every frame
as fully damaged and Intel's PSR2 / Panel Replay selective update refreshes the whole panel
every time. The patch fills the property from the damage KWin actually rendered, and falls back
to 0 whenever the damage isn't known (direct scanout, cursor and software layers, scaled or
transformed planes). The same change is proposed upstream as KWin MR !3548.

## Install

```
sudo dnf copr enable <owner>/kwin-damage
sudo dnf upgrade kwin kwin-common kwin-libs
```

Then log out and back in. Packages carry a `.fbdmgN` release suffix (`rpm -q kwin-libs`).
To go back to stock: `sudo dnf copr remove <owner>/kwin-damage && sudo dnf distro-sync kwin kwin-common kwin-libs`.

## How it updates

`.github/workflows/copr.yml` runs every 6 hours. It asks Koji for the newest `kwin` in
`fNN-updates` (the stable repo), and if COPR has no build of that version with the patch yet,
`make-srpm.sh` downloads Fedora's exact source RPM, checks the patch applies, adds it to the
spec as `Patch900`, tags the release, and submits the SRPM to COPR. A run fails, and GitHub
emails, if the patch stops applying or the COPR build fails.

When Fedora ships a new kwin, it can reach your machine a few hours before the patched build
does. The next `dnf upgrade` after the COPR build finishes puts the patch back.

Maintenance:

- Patch changed: replace the `.patch`, bump `TAG` (`fbdmg1` → `fbdmg2`), push.
- New Fedora release: add it to the workflow matrix and `copr-cli edit-chroot`/`modify --chroot`
  the project.
- The `COPR_CONFIG` secret is the contents of `~/.config/copr` from
  <https://copr.fedorainfracloud.org/api/>. The token expires after 180 days.
