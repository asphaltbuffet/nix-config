# Arcade cabinet: theme and per-game media are out-of-band content

The cabinet's attract-mode presentation uses the cosmo theme backed by per-game art from a HyperSpin media library. Neither the theme (341 MB) nor the media (~38 GB for our six systems) enters the flake or the Nix store. The flake describes only how attract-mode finds and renders them: layout names, artwork search paths, and display names.

This extends ADR-0010 from ROMs to art, for the same reasons — reproducibility without copyrighted multi-gigabyte blobs in jj history.

## Consequences

- ADR-0010's "correct-but-empty cabinet" widens: a freshly imaged cabinet has no games, no art, and default theming until content is synced out of band.
- Display names in `attract.cfg` are a functional join key, not a label. Cosmo's menu layouts resolve art by `[DisplayName]`, so display names follow cosmo's naming convention (`Nintendo Game Boy`, not `Game Boy`). Renaming a display breaks its art until the corresponding files are renamed too.
- attract-mode owns `attract.cfg` after the initial seed, so config changes that alter display sections require an explicit re-seed — deploying alone is not enough.
- HyperSpin's `ArtworkN` folder numbering is theme-relative, not semantic: the same number means different things per system. The source→slot mapping must be verified by inspection, never inferred.
- Media is **copied** to the cabinet, not symlinked to the NAS. The `arcade` kiosk user has no traverse permission on the NFS source (`grue`/root-owned, `sec=sys`), so symlinks would be unreadable by attract-mode; copying also keeps the front-end independent of the `x-systemd.automount` mount at browse time. The sync must therefore be run as `grue` or root, and the resulting tree chowned to the kiosk user.
- Cosmo exposes no shader on/off option. Its `crt.frag`/`crt.vert` files ship in every layout directory but are referenced by no `layout.nut` — dead files inherited from the theme's Robospin lineage. The only live shader is a bloom effect in `cosmo-arcade`, already gated by cosmo's own `enable_Lmarquee="No"` default. A declarative "disable shaders" toggle was designed and then dropped: there is nothing to disable, and the config line would have been silently ignored by attract-mode.
