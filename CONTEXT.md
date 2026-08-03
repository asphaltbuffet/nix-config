# nix-config

NixOS and home-manager configuration for a personal fleet of machines, managed as a single flake.

## Language

### Machines and identity

**Host**:
A physical machine managed by this flake. Each host has a directory under `nixos/hosts/<name>/` and is auto-discovered by the flake.
_Avoid_: node, machine, system, box

**Profile**:
A reusable NixOS-level bundle of system services and settings imported by one or more hosts. Lives in `nixos/profiles/`.
_Avoid_: preset, template, base config

**Role**:
A reusable home-manager-level bundle of user tools and settings imported by a user config. Lives in `home/roles/`.
_Avoid_: profile (reserved for the NixOS layer), preset

**Module**:
A single-tool home-manager configuration. Lives in `home/modules/<tool>/default.nix`. Imported from roles, never directly from user files. Most modules are thin *config-setters* — they set values against option interfaces home-manager already defines upstream, and declare no options of their own. An [[Interface module]] is the exception.
_Avoid_: plugin, package config, dotfiles

**Interface module**:
A module that *declares* its own `programs.<tool>.*` options rather than setting someone else's — written because home-manager has no upstream module for that tool. Held to upstream conventions (`enable`, `package`, typed submodules, no assumptions about the author's own setup) so it can be contributed to home-manager, after which the local copy is deleted and the option path stays identical. `programs.attract-mode` is the first.
_Avoid_: custom module, option module

**cli role**:
The `home/roles/cli.nix` role holding the shell/command-line foundation every login wants — zsh, git, starship, atuin, fzf and core CLI tools — with no graphical or desktop applications. The `desktop` role imports it and adds the desktop app suite; kiosk-style users (e.g. the arcade cabinet) import `cli` directly instead of `desktop`.
_Avoid_: shell role, base-shell

**desktop role**:
The `home/roles/desktop.nix` role: the `cli` role plus the desktop daily-driver applications (browser, password manager, chat, media). The baseline for a person's workstation login, not for a kiosk. Named `desktop` (not `base`) because `cli` is the actual foundation it builds on, and to avoid colliding with `nixos/profiles/base.nix`.
_Avoid_: base role (renamed), default role

**Arcade profile**:
The `nixos/profiles/arcade.nix` profile that turns a host into an arcade cabinet. Holds only system machinery (graphics, session autologin, audio, SSH access) — never the emulator or front-end applications themselves.
_Avoid_: arcade config, cabinet profile

**Arcade role**:
The `home/roles/arcade.nix` role holding the arcade cabinet's applications — the attract-mode front-end, a RetroArch build carrying one libretro core per console (NES, SNES, Game Boy, Genesis, Atari 2600), standalone MAME for arcade, and the matchbox window manager. Composed atop the `cli` role (not `desktop`) so the cabinet login gets a shell without the desktop app suite. The user-facing counterpart to the arcade profile.
_Avoid_: emulation role, mame role

**Core**:
A libretro emulator plugin loaded by RetroArch to emulate one console. The arcade cabinet's five consoles are cores in a single `retroarch` build; arcade emulation is standalone MAME, not a core.
_Avoid_: emulator (reserve for the standalone kind, e.g. MAME), plugin

**Core name**:
A core's self-reported display name, returned as `library_name` from `retro_get_system_info` — `Mesen`, `Snes9x`, `mGBA`, `Genesis Plus GX`, `Stella`. Distinct from the core's library filename (`mesen_libretro.so`) and from the arcade role's short key (`nes`), and derivable from neither: the casing is irregular and one contains spaces. RetroArch names a core's remap directory and file by this string, so it is what a [[Core remap]] path is built from. Read from the `.so`, never guessed.
_Avoid_: display name (overloaded), library name (the C field, not the concept), core (the plugin itself)

**Core remap**:
A RetroArch `.rmp` file at `remaps/<Core name>/<Core name>.rmp` that reassigns libretro's abstract pad buttons for one core — the per-system half of [[Control configuration]]. Resolution is first-match-wins across game, content-dir, then core scope, so a core remap always applies but is *replaced* wholesale by a narrower file rather than merged with one. Requires `remap_save_on_exit` and `input_remap_sort_by_controller_enable` both off, or RetroArch overwrites the file or reads a different path.
_Avoid_: remap file (ambiguous across the three scopes), controller config (that is MAME's term)

**Emulator definition**:
One entry in `programs.attract-mode.emulators`, describing how attract-mode launches a system: an executable, its arguments, a ROM path, and the file extensions to scan. Holds both kinds — RetroArch cores (built by the arcade role's `mkRetroArchEmulator` helper) and standalone MAME — because attract-mode has no core/emulator distinction; it only wants a command to run. Renders to one `~/.attract/emulators/<name>.cfg`. Contains *only* fields attract-mode itself understands; media-sync metadata is keyed separately by the same names (see [[Media mapping]]).
_Avoid_: emulator (the attrset key is `emulators`, but an entry is a *definition* — the emulator itself is the program), core (only some entries are cores)

**Control configuration**:
The declarative mapping from cabinet inputs to in-emulator actions, authored in Nix and rendered to each emulator's own format. Two halves with deliberately different granularity: consoles are configured per system as a [[Core remap]], because a pad layout is fixed across a console's library; MAME is configured per [[Control scope]], because arcade games range from one button to six plus a trackball. Covers only the virtual-pad-to-emulator and emulator-to-game layers — how the cabinet's encoder board presents itself as a gamepad is out of scope and handled once at the device level.
_Avoid_: keybinds, input config (attract-mode's own `inputMap` is a separate thing), controller mapping

**Control scope**:
The breadth at which one MAME control mapping applies. MAME's controller-config loader matches a `<system name="...">` block at five levels — `default`, source file (`cps2.cpp`, every game on that driver), parent set (`sf2`, that set and all its clones), BIOS root, and a single set — and resolves precedence itself at runtime. The Nix interface names the useful ones explicitly (`bySourceFile`, `byParent`, `bySet`) so intent is readable, but the sections describe MAME's matching rather than implementing it. Source-file scope is the workhorse: most cabinet control config is one rule per driver family, with per-set entries as exceptions.
_Avoid_: system (collides with the attract-mode display label, the Retrorama layout parameter, and MAME's own XML attribute), game (wrong for source-file and parent scope), level

**Controller config file**:
The single MAME XML file naming every [[Control scope]], selected with `-ctrlr` and found on `ctrlrpath`. MAME reads it and never writes it — unlike `cfg/<set>.cfg`, which MAME rewrites on every exit and which therefore stays unmanaged. Loaded before both `default.cfg` and the per-set file, so MAME's own saved settings still win; managing it takes nothing away from the cabinet. A `-ctrlr` naming a file that cannot be opened is a fatal error, not a degradation, so the flag and the file are derived from one Nix value.
_Avoid_: ctrlr file (fine in prose, but name the concept), cfg file (that is the one MAME owns), remap (RetroArch's term)

**Port mapping**:
The value of one [[Control scope]]: an attrset of MAME port type (`P1_BUTTON3`, `START1`, `UI_MENU`) to an input sequence string (`KEYCODE_C`, `JOYCODE_1_BUTTON2`, or an `OR`-joined combination). Renders to `<port type="..."><newseq type="standard">...</newseq></port>`. Scopes accumulate rather than replace — a broad scope sets the family's layout and a narrow one need only state its differences — which is the opposite of how a [[Core remap]] resolves. MAME's `<remap origcode= newcode=>` wholesale-substitution form is deliberately unimplemented; the option is a submodule so it can be added without a breaking change.
_Avoid_: binding, keymap, button map

**attract-mode config format**:
Not one format but two. `attract.cfg` uses a bare section header (`display` + tab + name) followed by tab-indented `key`-padded-to-20 + space + value lines, with filter contents doubly indented. `emulators/<name>.cfg` has no leading indent, pads keys to 20, and writes artwork as `artwork` padded to 10 + slot padded to 15 + path. Padding is a minimum, not a truncation. The parser treats spaces and tabs interchangeably, so the widths are cosmetic — matched only so Nix-written files diff cleanly against attract-mode-written ones.
_Avoid_: ini, tab-indented format (only one of the two is tab-indented)

**Display**:
One browsable view in attract-mode: a romlist to show, a layout to render it with, artwork paths, and optional filters. Independent of an [[Emulator definition]] — a display references a romlist by name, so several displays may share one emulator (e.g. "All" and "Favourites"), a display may span several, and an emulator may have no display. The arcade role happens to generate one display per emulator, but that 1:1 is the role's convention, not attract-mode's rule.
_Avoid_: system, screen, view, menu (the *displays menu* is the wheel that lists displays, not a display itself)

**Media mapping**:
The arcade role's separate, sync-side record of where each system's artwork comes from — the HyperSpin source folder and its per-slot `ArtworkN` subpaths. Keyed by the same names as the emulator definitions but deliberately *not* merged into them: it describes an out-of-band content library (ADR-0012), not anything attract-mode reads.
_Avoid_: media config, artwork definition

**Managed config** / **Seeded config**:
Two modes in which this flake can own an application's config file. *Managed* means Nix owns the file outright — it is a read-only store symlink, rewritten on every activation, and the Nix option is the single source of truth. *Seeded* means Nix writes the file once if absent and the application owns it thereafter; the Nix options describe only the initial state. Most tools here are managed; seeding is reserved for applications that rewrite their own config at runtime.
_Avoid_: templated, bootstrapped, initial config

**Romlist**:
attract-mode's index of the games available for one system, at `~/.attract/romlists/<name>.txt`. Built on the cabinet with `attract --build-romlist <name>` by scanning the emulator definition's rompath — never generated by the flake, because it is derived from ROMs, which are content (ADR-0010). For MAME, attract-mode additionally runs `mame -listxml` to attach real titles and metadata, triggered by the `info_source` field.
_Avoid_: game list, playlist, gamelist

### Users and secrets

**User config**:
The per-user home-manager entry point at `home/users/<name>.nix`. Imports roles, sets identity overrides (git name, email), and declares secret mappings.
_Avoid_: dotfile, home config, user profile

**Cross-host user**:
A user defined in `nixos/common/users.nix`, which every host imports — so such a user exists on *all* hosts. A user that should exist on only one host (e.g. a cabinet's `arcade` login) is instead defined in that host's own `configuration.nix`.
_Avoid_: shared user, global user

**Secret**:
A credential (API key, auth token) that lives exclusively in 1Password and never touches disk as a file. Injected into the shell environment at session start via `op inject`.
_Avoid_: key (overloaded), credential (use for the concept; secret for the managed artifact), env var (that's the injection mechanism, not the thing itself)

**Hardened SSH**:
The fleet's baseline SSH server hardening (no password auth, no keyboard-interactive, no root login, no X11 forwarding), extracted into `nixos/common/ssh-hardened.nix` and imported by any profile that exposes SSH — currently the server and arcade profiles.
_Avoid_: secure ssh, ssh config (overloaded — user SSH client config lives in `home/modules/ssh/`)

**Host key**:
The ed25519 SSH keypair that identifies a host to other SSH clients. Private key lives on the host at `/etc/ssh/ssh_host_ed25519_key`; public key is committed to the repo at `nixos/hosts/<name>/ssh_host_ed25519_key.pub` for agenix recipient lists and known-hosts management.
_Avoid_: machine key, SSH key (overloaded — also means user identity key)

### Deployment

**Bootstrap**:
The one-time process of installing NixOS on a new host from the installer ISO, generating the host key, and wiring the host into the flake. Executed by running `nixos-bootstrap` on the live ISO.
_Avoid_: provision, install, onboard

**Switch**:
Applying a new NixOS configuration to a running host and making it the boot default. User-only operation — never run by agents.
_Avoid_: deploy (use only for auto-deploy), apply, rebuild

**Auto-deploy**:
The automated pipeline where CI builds host closures and pushes store paths to a URL that opted-in hosts poll and apply on a timer. Distinct from a manual switch.
_Avoid_: auto-update, auto-upgrade, auto-switch

**Artifact dir**:
The directory `/home/nixos/bootstrap-<hostname>/` on the live ISO where `nixos-bootstrap` saves generated files (hardware config, host pubkey, instructions) for transfer to an existing host.
_Avoid_: output dir, bootstrap files

### Example dialogue

> **Dev:** I want to add bunyip as a new host. Do I create a profile for it?
>
> **Domain expert:** No — a profile is a reusable NixOS bundle shared across multiple hosts. What you want is a host directory under `nixos/hosts/bunyip/`. If bunyip needs the same system services as your other servers, you import the `server` profile from there.
>
> **Dev:** Got it. And for grue's shell tools on bunyip — I add those to the host config?
>
> **Domain expert:** No, those live in the user config at `home/users/grue.nix` via roles and modules. The host config only knows about system-level things. Home-manager wires the user config to the host through `nixos/common/users.nix`.
>
> **Dev:** Last one — after bootstrap, I need to get the hardware config back to my existing machine. Do I scp it?
>
> **Domain expert:** You transfer it from the artifact dir on the live ISO to your existing host. With kitty, use `kitten transfer` — it rides the SSH session so you don't need a separate connection.
