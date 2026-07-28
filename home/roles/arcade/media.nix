# home/roles/arcade/media.nix
#
# The cabinet's media mapping: where each system's artwork comes from, and which
# attract-mode artwork slots it fills. Deliberately NOT part of the emulator
# definitions (ADR-0014) — this describes an out-of-band HyperSpin content
# library (ADR-0012), not anything attract-mode reads.
#
# `hyperspinFolder` is the source folder name under the HyperSpin Media tree and
# is consumed only by scripts/arcade-media-sync.py. `slots` are the attract-mode
# artwork slots the cosmo layout for that system requests.
{
  # Where the sync script deposits art on the cabinet.
  root = "/mnt/roms/media";

  systems = {
    mame = {
      hyperspinFolder = "MAME";
      # No marquee/flyer: HyperSpin's MAME/Images holds only Wheel, plus genre
      # headers (Special) and one Pointer (Other).
      slots = ["wheel" "snap"];
    };
    nes = {
      hyperspinFolder = "Nintendo Entertainment System";
      slots = ["wheel" "snap" "boxart" "cartart"];
    };
    snes = {
      hyperspinFolder = "Super Nintendo Entertainment System";
      slots = ["wheel" "snap" "boxart" "cartart"];
    };
    genesis = {
      hyperspinFolder = "Sega Genesis";
      slots = ["wheel" "snap" "boxart" "cartart"];
    };
    gameboy = {
      hyperspinFolder = "Gameboy";
      # No cartridge scans exist for Game Boy in this library.
      slots = ["wheel" "snap" "boxart"];
    };
    atari2600 = {
      hyperspinFolder = "Atari 2600";
      # Cover art only; no cartridge scans.
      slots = ["wheel" "snap" "boxart"];
    };
  };
}
