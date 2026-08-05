# home/modules/retroarch/atari2600.nix
#
# Atari 2600, via the Stella core.
#
# `coreName` is the core's runtime `library_name`, read from
# `retro_get_system_info` in the built library. It names the remap directory
# and the file inside it, and follows from neither the nixpkgs attribute
# (`stella`) nor the library filename (`stella_libretro.so`).
#
# `buttons` is empty because a remap is RetroPad-to-RetroPad: meaningful
# values depend on what autoconfig assigns the attached device, which is an
# on-hardware observation rather than something derivable here.
_: {
  programs.retroarch.remaps.atari2600 = {
    coreName = "Stella";
    buttons = {};
  };
}
