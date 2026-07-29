# home/roles/arcade/media.nix
#
# The cabinet's media mapping: where each system's artwork comes from, and which
# attract-mode artwork slots it fills. Deliberately NOT part of the emulator
# definitions (ADR-0014) — this describes an out-of-band HyperSpin content
# library (ADR-0012), not anything attract-mode reads.
#
# `hyperspinFolder` is the source folder name under the HyperSpin Media tree and
# is consumed only by scripts/arcade-media-sync.py. `slots` are the attract-mode
# artwork slots synced for that system. `retroramaSystem` is the theme's own
# asset-folder name, which matches neither of the others.
{
  # Where the sync script deposits art on the cabinet.
  root = "/mnt/roms/media";

  systems = {
    mame = {
      hyperspinFolder = "MAME";
      retroramaSystem = "Arcade";
      # No marquee/flyer: HyperSpin's MAME/Images holds only Wheel, plus genre
      # headers (Special) and one Pointer (Other).
      slots = ["wheel" "snap"];
    };
    nes = {
      hyperspinFolder = "Nintendo Entertainment System";
      retroramaSystem = "Nintendo Entertainment System";
      slots = ["wheel" "snap" "boxart" "cartart"];
    };
    snes = {
      hyperspinFolder = "Super Nintendo Entertainment System";
      retroramaSystem = "Super Nintendo Entertainment System";
      slots = ["wheel" "snap" "boxart" "cartart"];
    };
    genesis = {
      hyperspinFolder = "Sega Genesis";
      retroramaSystem = "Sega Genesis";
      slots = ["wheel" "snap" "boxart" "cartart"];
    };
    gameboy = {
      hyperspinFolder = "Gameboy";
      # Retrorama ships no Game Boy folder; one is built by hand from HyperSpin
      # assets. Without it the layout points at a nonexistent directory.
      retroramaSystem = "Nintendo Game Boy";
      # No cartridge scans exist for Game Boy in this library.
      slots = ["wheel" "snap" "boxart"];
    };
    atari2600 = {
      hyperspinFolder = "Atari 2600";
      # Retrorama ships no Atari 2600 folder either; also built by hand.
      retroramaSystem = "Atari 2600";
      # Cover art only; no cartridge scans.
      slots = ["wheel" "snap" "boxart"];
    };
  };
}
