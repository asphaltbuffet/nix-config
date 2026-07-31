# igir curates the ROM library; its runbook is content and lives on the NAS

ADR-0011 deferred re-cutting the cabinet's stale MAME set, and `docs/references/mame-rom-recut.md` sketched the procedure with a hand-rolled `cp -n` loop plus a suggestion to reach outside nixpkgs for RomVault or ROMba. That has now been executed with **igir**, which is in nixpkgs (5.3.0) and does DAT-driven auditing, 1G1R selection, and merge-mode rebuilding in one tool. igir supersedes the copy loop: the loop can only forward files that already verify, whereas igir reorganizes split/merged/non-merged topology, which is the actual work a re-cut requires.

The operational runbook for this lives at `/nas/public/arcade-curated/README.md`, **not** in `docs/references/`. The commands hardcode NAS paths, name DAT files whose names carry datestamps, and get retuned whenever the DAT packs refresh — they are content operations on a mutable library, and ADR-0010 puts content outside the repo. A second copy in the flake would drift from the one beside the data. What stays in the repo is this ADR and the pointer in `mame-rom-recut.md`.

The scale is worth recording. The backup holds 51 system directories and ~640 GB. Curation produced 33 systems / 8,414 files / 76 GB of hardlinks: cartridge systems fell from ~15,000 files to 5,059 under a 1G1R policy, and the MAME set from 9,158 files (including both Neo Geo directories) to 3,205 files carrying 3,738 games. Against MAME 0.287, **4,093 of 42,650 machines verify complete** — the first factual answer to "how much of this set actually works", which is the question ADR-0011 left open.

## Findings that cost real time and would otherwise be rediscovered

**igir cannot write CHD.** Its only CHD-related flags are `--exclude-disks` and `.chd` in `--playlist-extensions`; it reads CHD but has no write path. Converting the ~209 GB of loose disc tracks needs `chdman` and is a separate project. Do not re-investigate whether igir can shrink the disc systems.

**MAME-sized 7z sets require `--input-checksum-quick`.** igir's default computes CRC32 + MD5 + SHA1, forcing full decompression of 364,583 ROM members across 8,869 archives. That run burned 1 day 14 hours of CPU over 16 hours wall clock, read 667 GB of a 371 GB set, and never finished. Reading the CRC32 that 7z already stores in each header — the field MAME DATs match on — completes the same audit in 20 minutes (~48x). The NAS was never the bottleneck: it streams at 83 MB/s measured while igir achieved ~2 MB/s, CPU-bound on decompression. The flag is mutually exclusive with `--input-checksum-max`.

**English-only must be enforced by region, never by language.** Only 139 of 2,373 SNES USA/Europe/World files carry an `En` tag (5.9%), because No-Intro tags language only on multi-language releases. `--filter-language EN` would discard ~94% of the wanted set. `--filter-region` is the correct mechanism, using igir's 3-letter codes (`EUR`, never `Europe`) — wrong codes yield a silently empty output.

**Hardlinking the backup required chowning it.** The tree was `root:root 750`; over NFS with `sec=sys` a non-root user cannot hardlink such files, and the error is `Operation not permitted`, not the `Invalid cross-device link` one expects from a filesystem-boundary problem. Directories additionally need the `+x` traverse bit — file ownership alone is insufficient. This is the same `sec=sys` ownership hazard ADR-0012 recorded for media symlinks, reappearing for hardlinks.

**Provenance is a real failure mode, and renaming cannot fix it.** `nes` and `atari7800` match TOSEC, not No-Intro (NES: 19/25 sampled CRCs against TOSEC, 0/25 against No-Intro). The sets are internally valid but from a different cataloguing lineage. Renaming is not a workaround because igir matches on checksum: our `10-Yard Fight (Japan)` and No-Intro's `10-Yard Fight (Japan) (En)` are both exactly 24,592 bytes with CRCs `08f0d1bd` and `44aa3eeb` — genuinely different dumps. TOSEC also carries no parent/clone data, so it can verify a set but never 1G1R it.

**The disc systems are a format mismatch.** Redump specifies `.bin` tracks plus a `.cue` sheet; `segacd` holds 759 `.wav` audio tracks, `neogeo_cd` 1,865 `.wav` alongside TOSEC-named `.rar`/`.pnr` archives, and `tgcd` uses `.iso`+`.cue`. Only `pcfx` has the right shape and still matches nothing. Zero matches here is a ripping-convention difference, not corruption.

**`neogeo` is a strict subset of `neogeo_aes`** — all 141 filenames appear in both (144 files), byte-identical by MD5. One physical set under two HyperSpin folder names. They must be passed as inputs to a single igir run so content-hash dedup collapses them; separate runs would carry the duplication to the cabinet.

## Considered Options

- **igir, with the runbook on the NAS** — chosen. One nixpkgs tool covers audit, 1G1R, and merge-mode rebuild; the runbook sits beside the data it operates on, so retuning the policy never touches the flake.
- **Keep the hand-rolled `cp -n` loop** — rejected. It cannot reorganize merge topology, which is most of what a MAME re-cut is, and it offers no verification beyond what `-verifyroms` already gives.
- **RomVault or ROMba** — rejected. Neither is in nixpkgs; both would need an out-of-tree fetch or a mono runtime for a job igir does natively.
- **Put the runbook in `docs/references/`** — rejected. It is a content operation full of absolute NAS paths and datestamped DAT filenames; ADR-0010 places that outside the repo, and two copies would drift.

## Consequences

- ADR-0011's re-cut is executed rather than deferred. The cabinet's real MAME coverage under 0.287 is 4,093 verified machines, recorded with per-run detail in the NAS runbook's changelog.
- `docs/references/mame-rom-recut.md` no longer describes the rebuild itself; Step 3 points at the NAS runbook. Its audit and swap steps remain valid.
- Curation does **not** expose new systems in attract-mode. Roughly 30 curated systems will sit on the cabinet with no emulator, display, or artwork until that downstream project runs — a deliberate widening of ADR-0010's "correct-but-empty cabinet".
- Six systems are knowingly uncurated and recorded as such in `systems.tsv`: `nes` and `atari7800` need a No-Intro-provenance set re-sourced; `famicom_disk_system` matches no DAT family and needs FDS header investigation; `rca_studio_ii` is 5 `.st2` files. Five more (`pcengine`, `supergrafx`, `wonderswan`, `wonderswan_color`, `channel_f`) are Japan-only or region-untagged libraries that the English-only filter empties entirely — working as specified, not a defect.
- The backup tree's ownership is now `grue:grue` rather than `root:root`. Any future process assuming root ownership there will need adjusting.
- `systems.tsv` stores **literal** DAT paths rather than globs, because DAT filenames contain both spaces and parentheses: a glob held in a shell variable is word-split on the spaces before it expands, and zsh reads the parentheses as glob qualifiers. `./curate.sh remap` re-resolves them after a DAT refresh.

## Postscript: the console scraper needed a key, not a curated set

Curating the library exposed a second, unrelated defect. Rebuilding the front-end index (`attract --build-romlist`) failed for every console system with `Error parsing json, text:` and an empty body. The cause is not the ROM set: attract-mode ships a shared thegamesdb.net project key that upstream has revoked, so scraping returns `403 Invalid API key was provided` with `remaining_monthly_allowance` 0. A personal key returns HTTP 200. Note that attract-mode-plus ships the *same* revoked key, so upgrading the front-end would not have fixed it.

Two things were needed. nixpkgs builds attract-mode without libcurl — its Makefile auto-detects the library via `pkg-config` (Makefile:299) and silently compiles the scraper out — so an overlay adds `curl` to `buildInputs`. Then `programs.attract-mode.thegamesdbKeyFile` supplies the key from an agenix secret at activation time, which is what amends ADR-0013's store-symlink mechanism. MAME is unaffected throughout: `info_source listxml` shells out to the local emulator rather than the network.
