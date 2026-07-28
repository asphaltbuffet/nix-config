# attract.cfg is Nix-managed; only the configure UI writes it

ADR-0010 required `attract.cfg` to be seeded rather than managed, on the premise that attract-mode rewrites it at runtime. That premise is wrong: `attract.cfg` is written only by `FeSettings::save()`, whose three call sites are all in the configure UI (`fe_config.cpp`, `fe_overlay.cpp`). Runtime state — current display, last launch — goes to a separate file, `attract.am`. So Nix can own `attract.cfg` as a read-only store symlink, and we do.

The cost is that settings changed through the Tab configure menu no longer persist; `programs.attract-mode.manageConfig = "seed"` restores the old behaviour for anyone who needs it. The gain is removing a silent deployment hazard: under seeding, a config change required deploying, deleting `attract.cfg` by hand, then activating again, and skipping the deletion produced a deploy that appeared to succeed while changing nothing.

## Consequences

- Supersedes ADR-0010's second consequence and ADR-0012's re-seed requirement. Activation is now sufficient.
- `attract.am` must remain unmanaged — it is runtime state, and resetting it would clear the cabinet's current display and launch history on every activation.
