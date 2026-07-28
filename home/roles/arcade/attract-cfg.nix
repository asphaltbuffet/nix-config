# home/roles/arcade/attract-cfg.nix
#
# Renders the initial ~/.attract/attract.cfg for the arcade cabinet from
# structured data, so attract-mode's tab-indented format is produced by the
# renderer (the only place a literal tab lives) rather than hand-maintained
# as invisible whitespace in a multi-line string.
#
# Consumed by home/roles/arcade/default.nix, which seeds this content once (attract-
# mode owns the file thereafter — see ADR-0010). Displays are generated from
# the `emulators` attrset the role already defines, so the system list has a
# single source of truth.
#
# Format: top-level `<header>` lines, each followed by tab-indented
# `\t<key>\t<value>` lines. `input_map` intentionally repeats keys (an action
# can map to several inputs), so each section is a LIST of {name, value}
# pairs — not an attrset, which could not hold duplicate keys.
{
  lib,
  emulators,
}: let
  # Emit one "<header>\n\t<key>\t<value>...\n" block. The literal tab (\t)
  # lives ONLY here.
  renderSection = {
    header,
    pairs,
  }:
    "${header}\n"
    + lib.concatMapStrings ({
      name,
      value,
    }: "\t${name}\t${value}\n")
    pairs;

  # Static global sections.
  staticSections = [
    {
      header = "general";
      pairs = [
        {
          name = "selection_max_step";
          value = "128";
        }
        {
          name = "confirm_favourites";
          value = "yes";
        }
      ];
    }
    {
      header = "sound";
      pairs = [
        {
          name = "sound_volume";
          value = "100";
        }
        {
          name = "ambient_volume";
          value = "100";
        }
        {
          name = "movie_volume";
          value = "100";
        }
      ];
    }
    {
      # Keyboard + first-joystick (Joy0) mappings. Joystick button numbers are
      # sane defaults to be remapped to real cabinet hardware via attract-mode's
      # `configure` (Tab) menu. Repeated action names are intentional.
      header = "input_map";
      pairs = [
        {
          name = "up";
          value = "Up";
        }
        {
          name = "up";
          value = "Joy0 Up";
        }
        {
          name = "down";
          value = "Down";
        }
        {
          name = "down";
          value = "Joy0 Down";
        }
        {
          name = "left";
          value = "Left";
        }
        {
          name = "left";
          value = "Joy0 Left";
        }
        {
          name = "right";
          value = "Right";
        }
        {
          name = "right";
          value = "Joy0 Right";
        }
        {
          name = "select";
          value = "Return";
        }
        {
          name = "select";
          value = "Joy0 Button0";
        }
        {
          name = "back";
          value = "Escape";
        }
        {
          name = "back";
          value = "Joy0 Button1";
        }
        {
          name = "exit";
          value = "LControl+Escape";
        }
        {
          name = "exit";
          value = "Joy0 Button7";
        }
        {
          name = "configure";
          value = "Tab";
        }
        {
          name = "prev_display";
          value = "LControl+Left";
        }
        {
          name = "next_display";
          value = "LControl+Right";
        }
        {
          name = "prev_letter";
          value = "LShift+Up";
        }
        {
          name = "next_letter";
          value = "LShift+Down";
        }
      ];
    }
    {
      # System-selection wheel. attract-mode generates the entries from the
      # configured displays, so no synthetic romlist is needed.
      header = "displays_menu";
      pairs = [
        {
          name = "layout";
          value = "cosmo-systems";
        }
      ];
    }
  ];

  # Cosmo layout per display. MAME gets the arcade layout; every console gets
  # the snes-n64 layout, which requests box/cart art instead of marquee/flyer.
  layoutFor = name:
    if name == "mame"
    then "cosmo-arcade"
    else "cosmo-snes-n64";

  # One display per emulator, generated from the shared `emulators` attrset.
  # `artwork` lines point at the out-of-band media tree (ADR-0010) — the paths
  # are declared here but the files arrive via the sync script.
  displaySections =
    lib.mapAttrsToList (name: def: {
      header = "display ${def.system}";
      pairs =
        [
          {
            name = "layout";
            value = layoutFor name;
          }
          {
            name = "romlist";
            value = name;
          }
        ]
        ++ map (slot: {
          name = "artwork";
          value = "${slot}\t/mnt/roms/media/${name}/${slot}";
        })
        def.artworkSlots;
    })
    emulators;

  allSections = staticSections ++ displaySections;
in
  "# Seeded once by home-manager; attract-mode owns this file thereafter.\n"
  + lib.concatStringsSep "\n" (map renderSection allSections)
