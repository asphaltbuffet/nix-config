# home/modules/retroarch/gameboy.nix
#
# Nintendo Game Boy, via the mGBA core.
#
# `coreName` is the core's runtime `library_name`, read from
# `retro_get_system_info` in the built library. It names the remap directory
# and the file inside it, and follows from neither the nixpkgs attribute
# (`mgba`) nor the library filename (`mgba_libretro.so`).
#
# `buttons` is empty because a remap is RetroPad-to-RetroPad: meaningful
# values depend on what autoconfig assigns the attached device, which is an
# on-hardware observation rather than something derivable here.
_: {
  programs.retroarch.remaps.gameboy = {
    coreName = "mGBA";
    buttons = {};
  };
}
