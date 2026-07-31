# Re-cutting the MAME ROM set to match current MAME

Level 2 SOP. Background and the decision this implements: `docs/adr/0011-mame-current-version-stale-romset.md`.

The cabinet's set is a split set from ~MAME 0.151 (Aug 2013 / Jan 2014); the cabinet runs whatever `pkgs.mame` provides (0.287+). This procedure audits what you have against current MAME and rebuilds it into a correct set.

## What re-cutting can and cannot do

**Can**: identify which sets are good/bad/incomplete under current MAME, reorganize split↔merged↔non-merged, rename machines that were renamed upstream, discard files no longer referenced, and produce a set whose surviving games are verified-correct.

**Cannot**: invent data. Machines dumped or redumped after 2013 have ROMs your set has never contained. Auditing will report them missing and no tool can conjure them — closing those gaps requires obtaining a newer source set. Re-cutting makes your set *correct and honest about its own contents*; it does not make it *complete*.

Budget accordingly: expect the output set to be smaller than the input, and expect the CHD/NAOMI subset (the 412 directories) to fare worst.

## Step 0 — work on a copy, never in place

Every step below is destructive-capable. `/mnt/roms/mame` is the live cabinet path referenced by the emulator definition; do not rebuild into it directly.

```bash
# On the cabinet, or wherever the set lives with enough free space.
SRC=/mnt/roms/mame
WORK=/mnt/roms/mame-recut
mkdir -p "$WORK"
df -h /mnt   # confirm free space >= size of the set
```

## Step 1 — generate the DAT for the MAME you actually run

The DAT is current MAME's manifest of every machine and the exact ROM checksums it expects. Generate it from the same binary the cabinet uses so there is no version skew:

```bash
mame -listxml > "$WORK/mame-0.287.xml"
```

This takes a while and produces a large file (hundreds of MB). It is the reference every subsequent step compares against.

## Step 2 — audit the existing set

MAME audits itself; no third-party tool needed for the report:

```bash
mame -rompath "$SRC" -verifyroms > "$WORK/audit-full.txt" 2>&1
```

This walks every machine MAME knows and reports `romset <name> is good` / `is bad` / `is incomplete` / `not found`. On ~9,700 sets against 45,000 machines this runs for a long time — let it finish.

Summarize the damage:

```bash
# Overall tallies
rg -o 'is (good|bad|incomplete)' "$WORK/audit-full.txt" | sort | uniq -c

# The games that will actually work
rg 'is good$' "$WORK/audit-full.txt" | awk '{print $2}' | sort > "$WORK/good.txt"
wc -l "$WORK/good.txt"

# Present but broken under 0.287 — the version-lock casualties
rg 'is bad|is incomplete' "$WORK/audit-full.txt" | awk '{print $2}' | sort > "$WORK/broken.txt"
wc -l "$WORK/broken.txt"
```

Audit CHDs separately — they are checked by a different flag and are the subset most likely to fail:

```bash
mame -rompath "$SRC" -verifyroms -verifysamples 2>&1 | tee "$WORK/audit-chd.txt"
```

At this point you have a factual answer to "how much of my set actually works", which is worth having even if you stop here.

## Step 3 — rebuild into a clean set

**Use igir.** It is in nixpkgs (this repo's `nix develop` provides it), and unlike a copy loop it reorganizes split/merged/non-merged topology — which is most of what a re-cut actually is. This supersedes the RomVault/ROMBa suggestion and the `cp -n` loop that previously lived here. See `docs/adr/0016-igir-curates-roms-runbook-on-nas.md`.

The runnable invocation lives with the data, not in this repo:

    /nas/public/arcade-curated/README.md

That runbook is the authoritative copy. Two points from it matter enough to repeat here:

- **`--input-checksum-quick` is effectively mandatory** for a MAME-sized 7z set. igir's default computes SHA1, forcing decompression of every ROM member; on this 371 GB / 8,869-archive set that ran 16+ hours without finishing. Reading the CRC32 that 7z already stores in each archive header — the field MAME DATs match on — completes the same audit in ~20 minutes.
- **The DAT must come from the MAME the cabinet actually runs** (Step 1 above). Sets are version-locked, so a mismatched DAT invalidates the entire rebuild.

A rebuild produces a set containing exactly the games current MAME can run. It is smaller and duller than a full set, but nothing in it fails at the cabinet. For reference, the 2026-07-30 run cut 9,158 files to 3,205, carrying 3,738 verified games out of the 42,650 machines MAME 0.287 knows.

Note the split-set caveat: a clone verifies good only when its parent is present. `--merge-roms split` handles this correctly; a name-based copy loop preserved it only by accident.

## Step 4 — verify the rebuilt set

Never trust a rebuild unaudited:

```bash
mame -rompath "$WORK/roms" -verifyroms 2>&1 | rg -c 'is good$'
mame -rompath "$WORK/roms" -verifyroms 2>&1 | rg 'is bad|is incomplete' | head
```

The first number should match `wc -l < "$WORK/good.txt"`. The second should print nothing.

## Step 5 — swap it in

Only after Step 4 is clean:

```bash
mv /mnt/roms/mame /mnt/roms/mame-old-0151
mv "$WORK/roms"   /mnt/roms/mame
```

Then rebuild the front-end index on the cabinet:

```bash
attract --build-romlist mame
```

Keep `mame-old-0151` until you are satisfied; it is the only copy of the games that did not survive the cut.

## Step 6 — no config change

Confirm this explicitly: nothing in the flake changes. The emulator definition points at `/mnt/roms/mame` and scans `.7z;<DIR>`; both remain true. That is ADR-0010's boundary working as intended — a content repair with a zero-line config diff.

## Filtering instead of re-cutting

If the goal is only "stop showing games that do not work", you do not need any of the above. Because the MAME emulator definition sets `info_source listxml`, attract-mode attaches MAME's own metadata to the romlist, and a display filter in attract-mode (Tab → Displays → Filters) can exclude non-working, BIOS, device, and clone entries without touching a single file on disk. That is the cheap path; re-cutting is the thorough one.
