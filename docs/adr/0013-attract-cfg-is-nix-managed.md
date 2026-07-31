# attract.cfg is Nix-managed; only the configure UI writes it

ADR-0010 required `attract.cfg` to be seeded rather than managed, on the premise that attract-mode rewrites it at runtime. That premise is wrong: `attract.cfg` is written only by `FeSettings::save()`, whose three call sites are all in the configure UI (`fe_config.cpp`, `fe_overlay.cpp`). Runtime state — current display, last launch — goes to a separate file, `attract.am`. So Nix can own `attract.cfg` as a read-only store symlink, and we do.

The cost is that settings changed through the Tab configure menu no longer persist; `programs.attract-mode.manageConfig = "seed"` restores the old behaviour for anyone who needs it. The gain is removing a silent deployment hazard: under seeding, a config change required deploying, deleting `attract.cfg` by hand, then activating again, and skipping the deletion produced a deploy that appeared to succeed while changing nothing.

## Amendment: a secret in the config makes it activation-written, not symlinked

Setting `programs.attract-mode.thegamesdbKeyFile` (added for the thegamesdb.net scraper key — see ADR-0016) changes *how* `attract.cfg` is produced, though not who owns it. A `home.file` entry's content becomes a Nix store path, and the store is world-readable, so interpolating a secret there would publish it. Instead the module renders the config with a placeholder, splits it on that placeholder at evaluation time, and an activation script concatenates head + key + tail using the key read from `/run/agenix`.

The decision this ADR records is unchanged: Nix owns the file, the configure UI's edits do not survive, and activation alone applies config changes with no manual deletion step. What differs is only the delivery mechanism, and it applies solely when a key file is configured — without one, `attract.cfg` remains a read-only store symlink exactly as described above.

Two properties are worth stating because they are what keep the original decision true. The rendered template still comes entirely from the module, so the file stays declarative; and because the script runs on every activation, a hand-edited `attract.cfg` is overwritten just as a store symlink would be. The file is written 0600 rather than the store's 0444, since it now carries a credential.

attract-mode offers no alternative that would have preserved the symlink: it reads no relevant environment variables (`getenv` serves only `HOME`/`HOMEDRIVE`/`HOMEPATH`), performs no variable expansion in config values, and its parser (`FeBaseConfigurable::load_from_file`) is a flat line reader with no `include` directive. Only `--config <dir>` exists, and pointing attract at a separate runtime directory was rejected as more machinery — a second directory and a changed launch command — for the same end state.

## Consequences

- Supersedes ADR-0010's second consequence and ADR-0012's re-seed requirement. Activation is now sufficient.
- `attract.am` must remain unmanaged — it is runtime state, and resetting it would clear the cabinet's current display and launch history on every activation.
- "`attract.cfg` is a store symlink" is true only when no secret-bearing option is set. Do not rely on the symlink itself — for instance, do not infer the active config's content by reading the store path, and expect `ls -l ~/.attract/attract.cfg` to show a regular file on the cabinet.
- Any future secret belonging in `attract.cfg` should reuse this mechanism rather than adding a second one. The placeholder-and-split approach generalises; a plain string option would leak into the store.
