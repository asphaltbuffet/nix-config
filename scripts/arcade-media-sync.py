#!/usr/bin/env python3
"""Sync HyperSpin media into the arcade cabinet's attract-mode media tree.

Out-of-band content tooling (ADR-0010/0012): NOT referenced by the flake. Run:
    nix run "nixpkgs#python3" -- scripts/arcade-media-sync.py --dry-run

Run as a user who can read the NFS media (grue or root) — NOT as the `arcade`
kiosk user, which has no traverse permission on the source paths. Art is COPIED
rather than symlinked for that same reason: attract-mode runs as `arcade` and
must not depend on the NAS automount at browse time. Remember to chown the
resulting tree to the kiosk user.

Matching is two-tier: exact ROM-stem match first, then normalized-title match
(regional/publisher metadata stripped). See the media design spec for measured
coverage per system.
"""
import argparse
import os
import re
import shutil
import sys

MEDIA = "/nas/public/arcade-drive-backup/hyperspin/Hyperspin/Media"
DEST = "/mnt/roms/media"
ROMS = "/mnt/roms"

# system attr -> (rom subdir, HyperSpin media folder(s), {slot: source subpath})
SYSTEMS = {
    "mame": ("mame", ["MAME"], {
        "wheel": "Images/Wheel",
        "snap": "Video",
    }),
    "nes": ("nes", ["Nintendo Entertainment System"], {
        "wheel": "Images/Wheel",
        "snap": "Video",
        "boxart": "Images/Artwork2",
        "cartart": "Images/Artwork3",
    }),
    "snes": ("snes", ["Super Nintendo Entertainment System"], {
        "wheel": "Images/Wheel",
        "snap": "Video",
        "boxart": "Images/Artwork3",
        "cartart": "Images/Artwork4",
    }),
    "genesis": ("genesis", ["Sega Genesis"], {
        "wheel": "Images/Wheel",
        "snap": "Video",
        "boxart": "Images/Artwork3",
        # Genesis is the one system with real cartridge scans, not a second
        # box variant. Verified by inspection.
        "cartart": "Images/Artwork4",
    }),
    "gameboy": ("gameboy", ["Gameboy", "Gameboy Color"], {
        "wheel": "Images/Wheel",
        "snap": "Video",
        # GB and GBC number their box art differently (Artwork2 vs Artwork4),
        # so this slot lists both — each source folder contributes whichever
        # subpath it actually has. No cartridge scans exist for either.
        "boxart": ["Images/Artwork2", "Images/Artwork4"],
    }),
    "atari2600": ("atari2600", ["Atari 2600"], {
        "wheel": "Images/Wheel",
        "snap": "Video",
        # Cover art only; no cartridge scans in this library.
        "boxart": "Images/Artwork3",
    }),
}

VIDEO_EXTS = (".mp4", ".flv")


def normalize(s):
    """Collapse a ROM or art name to a comparable title key."""
    s = re.sub(r"\(.*", "", s)
    s = re.sub(r"\[.*", "", s)
    s = s.lower()
    s = re.sub(r"[^a-z0-9 ]", "", s)
    return re.sub(r"\s+", " ", s).strip()


def build_index(names):
    """Map normalized title -> first source name with that title.

    Names that normalize to "" are skipped. A name beginning with `(` or `[`
    (e.g. "[Aladdin] Dizzy the Adventurer (USA)") collapses to the empty
    string, and storing that would make it a wildcard that silently answers
    every other empty-normalizing lookup with the wrong game's art.
    """
    idx = {}
    for n in names:
        key = normalize(n)
        if not key:
            continue
        idx.setdefault(key, n)
    return idx


def match(rom_stem, exact_set, norm_index):
    """Exact stem match first, then normalized title. None if neither hits."""
    if rom_stem in exact_set:
        return rom_stem
    key = normalize(rom_stem)
    if not key:
        return None
    return norm_index.get(key)


def listdir(d):
    return os.listdir(d) if os.path.isdir(d) else []


def stems_with_paths(dirs, exts=None):
    """{stem: fullpath} across several source dirs; first dir wins ties.

    `exts` is an ORDERED preference list, best first: where a stem exists in
    several formats, the earliest-ranked extension wins. This is what keeps
    .mp4 ahead of legacy .flv — roughly half the console Video dirs carry both,
    and relying on directory order would pick arbitrarily.
    """
    out = {}
    rank = {}
    for d in dirs:
        for fn in listdir(d):
            stem, ext = os.path.splitext(fn)
            ext = ext.lower()
            if exts and ext not in exts:
                continue
            r = exts.index(ext) if exts else 0
            if stem in out and rank[stem] <= r:
                continue
            out[stem] = os.path.join(d, fn)
            rank[stem] = r
    return out


def sync_slot(system, rom_dir, media_dirs, slot, subpath, dry_run):
    # A slot's subpath is normally one string, but may be a list when source
    # folders disagree on their ArtworkN numbering (see gameboy above). Build
    # the cross product and let stems_with_paths skip the ones that don't exist.
    subpaths = [subpath] if isinstance(subpath, str) else subpath
    src_dirs = [os.path.join(m, sp) for m in media_dirs for sp in subpaths]
    exts = VIDEO_EXTS if slot == "snap" else (".png",)
    art = stems_with_paths(src_dirs, exts)
    if not art:
        print("  %-8s SKIP (no source)" % slot)
        return
    exact = set(art)
    nidx = build_index(art.keys())
    dest = os.path.join(DEST, system, slot)
    if not dry_run:
        os.makedirs(dest, exist_ok=True)
    hits = 0
    misses = 0
    copied = 0
    for fn in listdir(rom_dir):
        rom_stem = os.path.splitext(fn)[0]
        m = match(rom_stem, exact, nidx)
        if m is None:
            misses += 1
            continue
        hits += 1
        src = art[m]
        target = os.path.join(dest, rom_stem + os.path.splitext(src)[1])
        if dry_run or os.path.exists(target):
            continue
        # Copy, never symlink: the kiosk user cannot read the NFS source
        # (grue/root-owned, sec=sys), and a symlinked front-end would stall on
        # the automount whenever the NAS is slow or down. Copy to a temp name
        # then rename, so an interrupted run never leaves a truncated file that
        # a later run would skip as "already present".
        tmp = target + ".part"
        shutil.copyfile(src, tmp)
        os.replace(tmp, target)
        copied += 1
    total = hits + misses
    pct = (100.0 * hits / total) if total else 0.0
    suffix = "" if dry_run else "  (+%d copied)" % copied
    print("  %-8s %5d/%-5d %5.1f%%%s" % (slot, hits, total, pct, suffix))


def selftest():
    cases = [
        ("3-D Tic-Tac-Toe (1980) (Atari, Carol Shaw - Sears) (CX2618)",
         "3-D Tic-Tac-Toe (1980) (Atari, Carol Shaw - Sears) (CX2618) ~", True),
        ("Activision Decathlon, The (USA)",
         "Activision Decathlon, The (1983) (Activision) [fixed] ~", True),
        ("2005 Minigame Multicart (USA) (Unl)", "2005 Minigame Multicart", True),
        ("Adventures of TRON (USA)", "A-Team, The (AKA Saboteur)", False),
        ("1941", "1941", True),
    ]
    failed = 0
    for rom, art, want in cases:
        got = match(rom, {art}, build_index([art])) is not None
        status = "ok  " if got == want else "FAIL"
        if got != want:
            failed += 1
        print("%s %-50s -> %s" % (status, rom[:50], got))
    print("selftest: %d failed" % failed)
    return 1 if failed else 0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--selftest", action="store_true")
    ap.add_argument("--system", help="only this system")
    args = ap.parse_args()

    if args.selftest:
        return selftest()

    for system, (romsub, mediafolders, slots) in SYSTEMS.items():
        if args.system and args.system != system:
            continue
        rom_dir = os.path.join(ROMS, romsub)
        media_dirs = [os.path.join(MEDIA, f) for f in mediafolders]
        print("%s (%d roms)" % (system, len(listdir(rom_dir))))
        for slot, subpath in slots.items():
            sync_slot(system, rom_dir, media_dirs, slot, subpath, args.dry_run)
    return 0


if __name__ == "__main__":
    sys.exit(main())
