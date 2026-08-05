# home/modules/retroarch/genesis.nix
#
# Sega Genesis, via the Genesis Plus GX core.
#
# `coreName` is the core's runtime `library_name`, read from
# `retro_get_system_info` in the built library. It names the remap directory
# and the file inside it, and follows from neither the nixpkgs attribute
# (`genesis-plus-gx`) nor the library filename (`genesis_plus_gx_libretro.so`).
#
# `buttons` is empty because a remap is RetroPad-to-RetroPad: meaningful
# values depend on what autoconfig assigns the attached device, which is an
# on-hardware observation rather than something derivable here.
_: {
  programs.retroarch.remaps.genesis = {
    coreName = "Genesis Plus GX";
    buttons = {};
  };
}
