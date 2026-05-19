# nixos/common/compat.nix — silence deprecation warnings; adopt new defaults early
_: {
  # New default in 26.11; false prevents forced pool import across machines.
  boot.zfs.forceImportRoot = false;
}
