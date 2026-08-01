# Control config targets the files the emulators never write

Declarative control configuration is written to MAME's `-ctrlr` file and RetroArch's `.rmp` remaps — deliberately *not* to `cfg/<set>.cfg`, which is the obvious home for per-game MAME input settings. Both emulators own a config file that they rewrite at runtime; we manage a different, read-only-by-design file in each, so Nix never competes with the emulator for the same path.

Granularity is asymmetric because the hardware is: consoles are configured per system (a pad layout is fixed across a console's library), MAME per [[Control scope]] (arcade games range from one button to six plus a trackball).

## Why not `cfg/<set>.cfg`

MAME rewrites that file on every exit, and it carries more than input — DIP switches, video settings. Managing it as a store symlink means either MAME's write fails or the cabinet silently loses those settings on each activation. The controller-config file has none of that problem: `configuration_manager::load_settings` (`src/emu/config.cpp`) reads it and there is no corresponding write path, and it is loaded *before* `default.cfg` and the per-set file — so MAME's own saved settings still win. Managing it takes nothing away from the cabinet.

It is also strictly more capable. Verified against MAME 0.287, the controller file is the only config type with multi-level matching: `default`, source file (`pong.cpp` — every game on that driver), parent set (clones inherit), BIOS root, and a single set. All matching scopes apply *cumulatively* in one run, so a broad rule sets a family's layout and a narrow one states only its differences. `cfg/` matches on the exact set name and nothing else, so the same coverage would mean one file per game with no inheritance — against a split ROM set (ADR-0011) full of clones, that is thousands of files.

## Why RetroArch needs two settings forced

`.rmp` files are only *conditionally* read-only. `remap_save_on_exit` defaults to true, and `input_remap_sort_by_controller_enable` changes the lookup path to `<Core name>/<sanitised device name>.rmp`, orphaning every managed file. Both are pinned off, with a build-time assertion if a conflicting value is set alongside declared remaps. Without that, a menu poke on the cabinet silently detaches the config from what Nix wrote — reintroducing exactly the "deploy appears to succeed, changes nothing" hazard ADR-0013 was written to eliminate.

## Considered Options

- **Per-game `cfg/<set>.cfg` files** — the obvious reading of "control config by game", rejected above: MAME owns those files, they carry non-input state, and they cannot express source-file or parent scope.
- **`input_remapping_path` for a single explicit remap file** — appears in RetroArch's sample `retroarch.cfg` but occurs **zero times** in the 1.22.2 source. It is a dead setting; the sample file has drifted from the code. Only `input_remapping_directory` is live, and it names a directory whose contents RetroArch keys by core.
- **One shared control abstraction across both emulators** — rejected because they share no vocabulary: RetroArch speaks libretro's fixed 16-button pad, MAME speaks per-driver port types (`P1_BUTTON3`, `START1`). A common layer would be lossy or become a permanently maintained translation.

## Consequences

- The `-ctrlr` flag and the file it names are derived from one Nix value and baked into a wrapped MAME (`programs.mame.finalPackage`). A `-ctrlr` naming an unopenable file is a **fatal error** — every game fails to launch, not degrades — so the flag must never be hand-typed.
- A misspelled [[Control scope]] key is ignored *silently*, with no diagnostic even at `-v`. Nix-side validation of the section keys is the only place that mistake is catchable; `mame -v <set>` lists the scopes that did apply.
- A [[Core remap]] path is built from the core's `library_name`, not its filename — `Mesen`, `Snes9x`, `mGBA`, `Genesis Plus GX`, `Stella`. The casing is irregular and one contains spaces; none are derivable from the `.so` name or the role's short key. Read them from the core, do not guess.
- The two halves resolve oppositely and this will trip up anyone who learns one first: MAME's scopes **accumulate**, RetroArch's remaps are **first-match-wins and replace wholesale**. A narrower `.rmp` must be complete; a narrower MAME scope need not be.
