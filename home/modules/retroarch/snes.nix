# home/modules/retroarch/snes.nix
#
# Super Nintendo Entertainment System, via the Snes9x core.
#
# `coreName` is the core's runtime `library_name`, read from
# `retro_get_system_info` in the built library. It names the remap directory
# and the file inside it, and follows from neither the nixpkgs attribute
# (`snes9x`) nor the library filename (`snes9x_libretro.so`).
#
# The face buttons are swapped in both pairs because SDL names buttons by the
# Xbox convention (A bottom, B right) while Nintendo's layout is rotated
# relative to it: the Retrolink SNES pad autoconfigures as
# `a:b2,b:b1,x:b3,y:b0`, which lands A/B and X/Y transposed for SNES titles.
# Observed on the cabinet with Super Mario World.
#
# The remap is RetroPad-to-RetroPad, so the correction is two symmetric swaps
# rather than a physical rewiring. It is declared per core, which is why it
# does not disturb the other systems sharing the same pad.
_: {
  programs.retroarch.remaps.snes = {
    coreName = "Snes9x";
    buttons = {
      a = "b";
      b = "a";
      x = "y";
      y = "x";
    };
  };
}
