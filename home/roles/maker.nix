# home/roles/maker.nix
# Designing physical objects and preparing them for fabrication: CAD, mesh
# viewing/repair, and slicing for the household 3D printer (Prusa i3 MK3S).
# Workstation-only (ADR-0026). Stops at the slicer — OctoPrint runs on its own
# Raspberry Pi outside this flake; OrcaSlicer's printer profile and OctoPrint
# URL/API key are set once in its GUI, not managed here.
{
  pkgs,
  lib,
  osConfig,
  ...
}: {
  config = lib.mkIf osConfig.host.workstation {
    home.packages = with pkgs; [
      freecad
      openscad-unstable # stable `openscad` is 2021.01, without the Manifold backend
      solvespace
      orca-slicer
      f3d # STL/3MF/STEP viewer + Dolphin thumbnailer
      meshlab # mesh repair
    ];

    # OpenSCAD searches this directory regardless of how it was launched,
    # unlike OPENSCADPATH, which only reaches session-inherited environments.
    xdg.dataFile."OpenSCAD/libraries/BOSL2".source = "${pkgs.openscadPackages.bosl2}/share/openscad/libraries/BOSL2";
  };
}
