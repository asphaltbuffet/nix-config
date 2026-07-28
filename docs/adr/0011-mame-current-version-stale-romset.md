# MAME tracks nixpkgs; a period-stale ROM set is fixed as content, not by pinning the config

The arcade role ships whatever `pkgs.mame` nixpkgs currently provides (0.287 at the time of writing). The cabinet's MAME ROM set is a split set dated August 2013 / January 2014, i.e. roughly MAME 0.149–0.151 — about twelve years older than the emulator that will run it. We accept the resulting partial breakage rather than pinning MAME to a period-correct release.

MAME ROM sets are **version-locked**: MAME validates each set against the internal database for its exact release, and sets are re-cut between versions as bad dumps are corrected and machine definitions are split or renamed. Running a 2013 set on 0.287 means a meaningful fraction of games fail with checksum or "ROM needs redump" errors. The failure is silent and per-game — the cabinet works, the front-end lists everything, and individual titles simply refuse to boot. A future reader hitting this will reasonably suspect a configuration bug, which is why it is recorded here: it is a known, accepted state, not a defect.

Breakage concentrates in the 412 CHD-based directories (largely Sega NAOMI/Atomiswave GD-ROM titles). Those platforms saw substantial emulation changes after 2014 and the CHD container format itself was revised (v4 → v5), so the CHD subset is the least likely to work untouched.

The decisive argument against pinning is ADR-0010's boundary. That ADR establishes that the flake holds *config* and the cabinet holds *content*, with ROMs deliberately outside the repo and the Nix store. A stale ROM set is a **content** problem. Solving it by freezing a twelve-year-old C++ codebase into an otherwise-current flake would fix a content defect on the config side of the boundary — and would mean maintaining an old MAME against nixpkgs drift (SDL, compiler, toolchain) indefinitely, with no upstream fixes, forever. The correct repair is re-cutting the ROM set to match current MAME, which is an out-of-band content operation requiring no config change at all. See `docs/references/mame-rom-recut.md`.

## Considered Options

- **Pin a period-correct MAME (~0.151) via an overlay** — highest compatibility with the ROMs actually on the cabinet, rejected because it inverts the maintenance burden, freezes the config against upstream, and solves a content problem on the config side of ADR-0010's boundary.
- **Re-cut the ROM set to match current MAME** — the correct long-term fix, and the intended one; deferred rather than rejected. It is pure content work on multi-gigabyte data, so it is not something the flake performs.
- **Curate a small verified subset** — best cabinet UX and sidesteps breakage almost entirely, rejected as the *config-level* answer because it discards ~9,000 games permanently. Retained as a future attract-mode display *filter*, which the `info_source listxml` metadata makes possible without regenerating anything.

## Consequences

- Expect per-game failures with no config-level cause. Diagnose with `mame -verifyroms <name>`, not by editing the flake.
- The emulator definition must not be "fixed" by pointing at an older MAME. If compatibility becomes intolerable, re-cut the content.
- Because `info_source listxml` attaches MAME's own metadata (real titles, clone/parent, working status) to the romlist, non-working sets can be filtered out in attract-mode rather than deleted from disk.
