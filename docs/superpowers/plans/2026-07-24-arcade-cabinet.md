# Arcade Cabinet Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an `arcade` NixOS host — a kiosk cabinet that autologins into the attract-mode front-end over bare X, running RetroArch (five console cores) plus standalone MAME, reachable via SSH/Tailscale and self-updating via auto-deploy.

**Architecture:** A new `nixos/profiles/arcade.nix` holds system machinery (graphics, PipeWire, autologin + startx, hardened SSH); a new `home/roles/arcade.nix` holds the applications and X session; a new `nixos/hosts/arcade/` wires them together and defines a machine-local `arcade` user. Two supporting refactors extract shared pieces first: `home/roles/cli.nix` (shell foundation split out of `base`) and `nixos/common/ssh-hardened.nix` (SSH hardening shared by `server` and `arcade`). Neither refactor changes behavior for existing hosts.

**Tech Stack:** NixOS, home-manager, Nix flakes, alejandra (formatter), statix (linter), `just` (task runner), `nh` (nix helper), `jj` (VCS — colocated with git).

## Global Constraints

- **VCS is `jj`, never `git`.** Use `jj file track <path>` to track new files; never `git add`. Commits are made with `jj commit -m "..."` (or the repo's normal jj flow).
- **New files must be tracked before building.** The flake copies sources via `self`; an untracked `.nix` file is invisible to `just build`. Run `jj file track <path>` immediately after creating any new `.nix` file.
- **Formatter is alejandra, enforced by `nix flake check`.** Run `just fmt` before every commit.
- **Linter is statix.** `just lint` is read-only; `just fmt` fixes formatting + dead code.
- **`server.nix` and `laptop/` are mutually exclusive.** The arcade profile imports neither.
- **`pkgs.system` is deprecated** — use `pkgs.stdenv.hostPlatform.system` if a system string is ever needed.
- **Binary caches:** use `extra-substituters` / `extra-trusted-public-keys` (append), never bare `substituters` (replace). Not needed in this plan — `base.nix` already provides them.
- **Never run `just switch`** (alters boot default on the live system — user-only). `just test` requires user approval. Agents verify with `just build <host>` only.
- **`stateVersion` for the arcade host is `"26.11"`** (matches the most recently installed host, `bunyip`).
- **The `arcade` user needs zero secrets** — no agenix recipient entry, no `secrets.nix` change.

---

## File Structure

**Created:**
- `home/roles/cli.nix` — shell/CLI foundation (extracted from `base.nix`): shell modules + core CLI packages, no GUI apps.
- `nixos/common/ssh-hardened.nix` — the fleet's baseline hardened-SSH settings module.
- `nixos/profiles/arcade.nix` — arcade cabinet system machinery (graphics, PipeWire, autologin + startx, imports `ssh-hardened.nix`).
- `home/roles/arcade.nix` — arcade applications (attract-mode, RetroArch + cores, MAME, matchbox) + declarative X session.
- `nixos/hosts/arcade/configuration.nix` — host entry point; imports `base.nix` + arcade profile; defines machine-local `arcade` user.
- `nixos/hosts/arcade/hardware-configuration.nix` — placeholder until bootstrap generates the real one.

**Modified:**
- `home/roles/base.nix` — becomes `cli` role import + the desktop GUI modules/packages only.
- `nixos/profiles/server.nix` — imports `ssh-hardened.nix` instead of inlining the openssh hardening block.

**Docs already written during design (no task needed):** `CONTEXT.md` terms, `docs/adr/0009-arcade-bare-x-startx-kiosk.md`, `docs/adr/0010-arcade-config-content-boundary.md`.

---

## Task 1: Extract the `cli` role from `base`

Split the shell/CLI foundation out of `home/roles/base.nix` into a new `home/roles/cli.nix`, so kiosk users can import the shell foundation without the desktop app suite. `base.nix` then imports `cli` and adds only the GUI pieces. **This must not change the closure of any existing user** (`grue`, `sukey`, `jsquats` all import `base`, which must still resolve to the same set of modules and packages).

**Files:**
- Create: `home/roles/cli.nix`
- Modify: `home/roles/base.nix`

**Interfaces:**
- Produces: `home/roles/cli.nix` — importable role providing zsh, git, starship, atuin, fzf, tmux, zoxide, eza, vim, wishlist, nix-index, and core CLI packages (`bat curl fd just ripgrep sd unzip wget xh zip`), plus `xdg.enable`, `fonts.fontconfig.enable`, `home-manager.enable`, `nix-index-database.comma.enable`, `programs.fzf.enable`, and the `sessionVariables` (EDITOR/LANG/PAGER). Consumed by `base.nix` and `arcade.nix`.
- Produces: `home/roles/base.nix` — unchanged public behavior: importing it yields `cli` + GUI modules (`1password kitty mullvad signal firefox`) + GUI packages (`discord vlc`).

- [ ] **Step 1: Capture the current `base` closure as a baseline**

Before touching anything, record what `base` currently produces so we can prove the refactor is behavior-preserving. Build a host that uses `base` (every host does, via a user).

Run: `just build wendigo 2>&1 | tail -5 && nix path-info --recursive ".#nixosConfigurations.wendigo.config.system.build.toplevel" 2>/dev/null | sort > /tmp/arcade-baseline-wendigo.txt; wc -l /tmp/arcade-baseline-wendigo.txt`
Expected: build succeeds; a non-empty file of store paths is written. (If the machine can't evaluate `wendigo`'s hardware, substitute any host that builds cleanly and use it consistently in Step 5.)

- [ ] **Step 2: Create `home/roles/cli.nix` with the shell foundation**

Create `home/roles/cli.nix`:

```nix
# home/roles/cli.nix
# Shell / command-line foundation. Every login wants this; it contains no
# graphical or desktop applications. The `base` role imports it and adds the
# desktop app suite; kiosk users (e.g. the arcade cabinet) import `cli` directly.
{
  pkgs,
  lib,
  inputs,
  ...
}: {
  imports = [
    inputs.nix-index-database.homeModules.nix-index

    ../modules/atuin
    ../modules/eza
    ../modules/fzf
    ../modules/git
    ../modules/starship
    ../modules/tmux
    ../modules/vim
    ../modules/zoxide
    ../modules/zsh
    ../modules/wishlist
  ];

  xdg.enable = true;
  fonts.fontconfig.enable = true;

  programs = {
    home-manager.enable = true;
    nix-index-database.comma.enable = true;
    fzf.enable = true;
  };

  home = {
    packages = with pkgs; [
      bat
      curl
      fd
      just
      ripgrep
      sd
      unzip
      wget
      xh
      zip
    ];

    sessionVariables = {
      EDITOR = lib.mkDefault "nvim";
      LANG = "en_US.UTF-8";
      PAGER = lib.mkDefault "less";
    };
  };
}
```

- [ ] **Step 3: Track the new file**

Run: `jj file track home/roles/cli.nix`
Expected: no error.

- [ ] **Step 4: Rewrite `home/roles/base.nix` to import `cli` + the GUI-only pieces**

Replace the entire contents of `home/roles/base.nix` with:

```nix
# home/roles/base.nix
# The `cli` shell foundation plus the desktop daily-driver applications.
# Baseline for a person's workstation login — not for a kiosk (see cli.nix).
{pkgs, ...}: {
  imports = [
    ./cli.nix

    # GUI stuff
    ../modules/firefox
    ../modules/1password
    ../modules/kitty
    ../modules/mullvad
    ../modules/signal
  ];

  home.packages = with pkgs; [
    # GUI stuff
    discord
    vlc
  ];
}
```

- [ ] **Step 5: Prove the refactor is behavior-preserving**

Rebuild the same host and diff the closure against the baseline. `just fmt` first so formatting differences don't cause noise.

Run: `just fmt && just build wendigo 2>&1 | tail -5 && nix path-info --recursive ".#nixosConfigurations.wendigo.config.system.build.toplevel" 2>/dev/null | sort > /tmp/arcade-after-wendigo.txt; diff /tmp/arcade-baseline-wendigo.txt /tmp/arcade-after-wendigo.txt && echo "IDENTICAL CLOSURE"`
Expected: `IDENTICAL CLOSURE` — the store path set is unchanged, proving no existing user's environment changed. (Use whichever host you baselined in Step 1.)

- [ ] **Step 6: Lint and commit**

Run: `just lint && just fmt`
Expected: no lint errors; formatting clean.

```bash
jj commit -m "refactor(home): extract cli role from base

Split the shell/CLI foundation out of base into a new cli role so kiosk
users can get a working shell without the desktop app suite. base now
imports cli and adds only GUI modules/packages. Closure of existing
users is unchanged (verified against wendigo)."
```

---

## Task 2: Extract the `ssh-hardened` common module

Pull the SSH hardening settings out of `nixos/profiles/server.nix` into `nixos/common/ssh-hardened.nix`, so both `server` and the forthcoming arcade profile share one authoritative hardening definition. **Must not change `server`'s behavior.**

**Files:**
- Create: `nixos/common/ssh-hardened.nix`
- Modify: `nixos/profiles/server.nix`

**Interfaces:**
- Produces: `nixos/common/ssh-hardened.nix` — importable module that enables `services.openssh` with `PasswordAuthentication = false`, `KbdInteractiveAuthentication = false`, `PermitRootLogin = "no"`, `X11Forwarding = false`. Consumed by `server.nix` and `arcade.nix`.

- [ ] **Step 1: Baseline the `server` host closure**

`bunyip` is the server host (the only host that imports `server.nix`). Baseline it.

Run: `just build bunyip 2>&1 | tail -5 && nix path-info --recursive ".#nixosConfigurations.bunyip.config.system.build.toplevel" 2>/dev/null | sort > /tmp/arcade-baseline-server.txt; wc -l /tmp/arcade-baseline-server.txt`
Expected: build succeeds; non-empty baseline file.

- [ ] **Step 2: Create `nixos/common/ssh-hardened.nix`**

Create `nixos/common/ssh-hardened.nix`:

```nix
# nixos/common/ssh-hardened.nix
# The fleet's baseline SSH server hardening. Import from any profile that
# exposes SSH (server, arcade). Deliberately independent of the CUPS/Avahi/
# monitoring bundle in server.nix so single-purpose hosts can harden SSH
# without pulling in a print server.
{...}: {
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
      X11Forwarding = false;
    };
  };
}
```

- [ ] **Step 3: Track the new file**

Run: `jj file track nixos/common/ssh-hardened.nix`
Expected: no error.

- [ ] **Step 4: Rewrite `server.nix` to import the shared module**

Replace the entire contents of `nixos/profiles/server.nix` with:

```nix
# nixos/profiles/server.nix
# Headless server profile. Import alongside base.nix for home-lab nodes.
# Do NOT import laptop/ with this profile — they are mutually exclusive.
{...}: {
  imports = [
    ../common/ssh-hardened.nix
    ../common/tailscale-subnet-router.nix
    ../common/monitoring.nix
  ];

  # CUPS print server — serve printers to the network via mDNS/Bonjour
  services = {
    printing.enable = true;
    avahi = {
      enable = true;
      nssmdns4 = true;
    };
  };
}
```

- [ ] **Step 5: Prove `server` behavior is unchanged**

Run: `just fmt && just build bunyip 2>&1 | tail -5 && nix path-info --recursive ".#nixosConfigurations.bunyip.config.system.build.toplevel" 2>/dev/null | sort > /tmp/arcade-after-server.txt; diff /tmp/arcade-baseline-server.txt /tmp/arcade-after-server.txt && echo "IDENTICAL CLOSURE"`
Expected: `IDENTICAL CLOSURE`.

- [ ] **Step 6: Lint and commit**

Run: `just lint && just fmt`
Expected: clean.

```bash
jj commit -m "refactor(nixos): extract ssh-hardened common module

Pull the openssh hardening out of server.nix into a shared
common/ssh-hardened.nix so the arcade profile can reuse the same
settings without importing the server print-server bundle. server
closure unchanged (verified against bunyip)."
```

---

## Task 3: Create the `arcade` system profile

Add `nixos/profiles/arcade.nix` with the cabinet's system machinery: graphics, PipeWire audio, autologin into a bare-X `startx` session, and the shared SSH hardening. Networking, Tailscale, substituters, and the base openssh enable are all inherited from `base.nix` and deliberately NOT repeated here. This task's build verification happens in Task 5 (the profile isn't consumed by any host until then), so here we verify it *evaluates* by building it into a throwaay check via the host in Task 5 — for now we lint/format and confirm it parses.

**Files:**
- Create: `nixos/profiles/arcade.nix`

**Interfaces:**
- Consumes: `nixos/common/ssh-hardened.nix` (Task 2).
- Produces: `nixos/profiles/arcade.nix` — importable profile. Sets `hardware.graphics.enable`, `services.pipewire.*`, `services.getty.autologinUser = "arcade"`, `services.xserver.enable` + `services.xserver.displayManager.startx.enable`. Expects a user named `arcade` to exist (provided by the host in Task 5).

- [ ] **Step 1: Create `nixos/profiles/arcade.nix`**

Create `nixos/profiles/arcade.nix`:

```nix
# nixos/profiles/arcade.nix
# Arcade cabinet system machinery. Import alongside base.nix.
# Holds ONLY privileged system plumbing — the emulators, front-end, and X
# session live in the `arcade` home-manager role (home/roles/arcade.nix).
#
# Inherited from base.nix, so NOT repeated here: networkmanager, tailscale,
# nix substituters, openssh enable. See ADR-0009 (bare X kiosk) and
# ADR-0010 (config/content boundary).
#
# Do NOT import server.nix or laptop/ — this is a standalone host type.
{...}: {
  imports = [
    ../common/ssh-hardened.nix
  ];

  # GL for MAME / RetroArch. Generic Mesa enable covers Intel/AMD.
  # NVIDIA would additionally need hardware.nvidia + videoDrivers; deferred.
  hardware.graphics.enable = true;

  # Audio. The cabinet has no Plasma desktop to pull PipeWire in implicitly
  # (unlike the laptop hosts), so configure it explicitly here.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # Kiosk boot: autologin the arcade user on tty1. The user's login shell
  # (managed in the arcade home-manager role) runs `exec startx` there, and
  # the X session execs attract-mode. No display manager, no desktop.
  services.getty.autologinUser = "arcade";

  services.xserver = {
    enable = true;
    displayManager.startx.enable = true;
  };
}
```

- [ ] **Step 2: Track the new file**

Run: `jj file track nixos/profiles/arcade.nix`
Expected: no error.

- [ ] **Step 3: Format and lint (evaluation is verified in Task 5)**

Run: `just fmt && just lint`
Expected: clean. (A standalone profile isn't buildable in isolation; Task 5 builds it via the host.)

- [ ] **Step 4: Commit**

```bash
jj commit -m "feat(nixos): add arcade cabinet system profile

System machinery for a kiosk arcade host: Mesa graphics, explicit
PipeWire audio (no Plasma to bring it), tty1 autologin, and bare-X
startx. SSH hardening via the shared ssh-hardened module. Networking/
tailscale/substituters inherited from base.nix. See ADR-0009."
```

---

## Task 4: Create the `arcade` home-manager role

Add `home/roles/arcade.nix` with the cabinet applications (attract-mode, RetroArch with five cores, standalone MAME, matchbox WM) and the declarative X session: an `.xinitrc` that starts matchbox and execs attract-mode, plus a login-shell guard that runs `exec startx` on tty1. Built and verified in Task 5 via the host.

**Files:**
- Create: `home/roles/arcade.nix`

**Interfaces:**
- Consumes: `home/roles/cli.nix` (Task 1) for the shell foundation.
- Produces: `home/roles/arcade.nix` — importable role. Installs `attract-mode`, a `retroarch.withCores` build, `mame`, `matchbox-window-manager`; writes `~/.xinitrc`; sets the tty1 `startx` guard via `programs.zsh.loginExtra`. Expects the importing user to be the autologin user from the arcade profile (Task 3).

- [ ] **Step 1: Create `home/roles/arcade.nix`**

Create `home/roles/arcade.nix`. Note on core names: the libretro core attribute names below are the current nixpkgs names; if evaluation in Task 5 reports one missing, run `nix search nixpkgs libretro` to find the renamed attribute and substitute it.

```nix
# home/roles/arcade.nix
# Arcade cabinet applications and X session. Imported by the machine-local
# `arcade` user. Composed atop the `cli` role (NOT `base`) so the kiosk login
# gets a shell without the desktop app suite.
#
# ROMs are out-of-band content at ~/roms/<system>/ (see ADR-0010) — this role
# describes how to launch them, never the ROM files themselves.
{pkgs, ...}: let
  # One RetroArch build carrying exactly the five console cores. Verify core
  # attr names with `nix search nixpkgs libretro` if any fails to evaluate.
  retroarchWithCores = pkgs.retroarch.withCores (cores:
    with cores; [
      mesen # NES
      snes9x # SNES
      mgba # Game Boy / GBA
      genesis-plus-gx # Sega Genesis
      stella # Atari 2600
    ]);
in {
  imports = [
    ./cli.nix
  ];

  home.packages = [
    pkgs.attract-mode
    retroarchWithCores
    pkgs.mame
    pkgs.matchbox-window-manager
  ];

  # X session: start a featherweight WM in the background (handles focus/
  # fullscreen when emulators spawn their own windows), then exec the
  # front-end. When attract-mode exits, X exits.
  home.file.".xinitrc" = {
    executable = true;
    text = ''
      #!/bin/sh
      ${pkgs.matchbox-window-manager}/bin/matchbox-window-manager &
      exec ${pkgs.attract-mode}/bin/attract
    '';
  };

  # On the autologin tty (tty1) with no X yet, launch the graphical session.
  # Guarded so SSH logins and other TTYs get a normal shell.
  programs.zsh.loginExtra = ''
    if [ -z "$DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
      exec startx
    fi
  '';
}
```

- [ ] **Step 2: Track the new file**

Run: `jj file track home/roles/arcade.nix`
Expected: no error.

- [ ] **Step 3: Format and lint**

Run: `just fmt && just lint`
Expected: clean. (Built via the host in Task 5.)

- [ ] **Step 4: Commit**

```bash
jj commit -m "feat(home): add arcade cabinet role

attract-mode front-end, a RetroArch build with NES/SNES/GB/Genesis/2600
cores, standalone MAME, and matchbox. Declarative .xinitrc (matchbox +
exec attract) and a tty1-guarded exec startx in the login shell.
Composed atop cli, not base. See ADR-0009 / ADR-0010."
```

---

## Task 5: Create the `arcade` host and build the whole thing

Add `nixos/hosts/arcade/` wiring the profile and role together, defining the machine-local `arcade` user (per the design: defined in the host, NOT in `common/users.nix`, so it exists only on this host). This is the task where the profile (Task 3) and role (Task 4) are first evaluated and built end-to-end.

**Files:**
- Create: `nixos/hosts/arcade/configuration.nix`
- Create: `nixos/hosts/arcade/hardware-configuration.nix`

**Interfaces:**
- Consumes: `nixos/profiles/base.nix`, `nixos/profiles/arcade.nix` (Task 3), `home/roles/arcade.nix` (Task 4).
- Produces: `nixosConfigurations.arcade` (auto-discovered by the flake from the directory name).

- [ ] **Step 1: Create a placeholder `hardware-configuration.nix`**

The real one is generated by `nixos-generate-config` during bootstrap on the physical machine. A minimal placeholder lets the config evaluate now. Create `nixos/hosts/arcade/hardware-configuration.nix`:

```nix
# nixos/hosts/arcade/hardware-configuration.nix
# PLACEHOLDER — replace with the output of `nixos-generate-config` generated
# on the physical cabinet during bootstrap (real filesystems, kernel modules,
# and CPU microcode go here). This stub only lets the flake evaluate before
# the machine is installed. Do NOT deploy with this stub in place.
{lib, ...}: {
  boot.initrd.availableKernelModules = ["xhci_pci" "ahci" "nvme" "usbhid" "sd_mod"];
  boot.loader.systemd-boot.enable = lib.mkDefault true;

  # Placeholder root filesystem — the real device/UUID comes from bootstrap.
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
```

- [ ] **Step 2: Create the host `configuration.nix`**

Create `nixos/hosts/arcade/configuration.nix`. The `arcade` user and its home-manager mapping are defined *here*, not in `common/users.nix`, so the user exists only on this host.

```nix
{pkgs, ...}: {
  imports = [
    ./hardware-configuration.nix

    ../../common/users.nix

    ../../profiles/base.nix
    ../../profiles/arcade.nix
  ];

  networking.hostName = "arcade";

  # Machine-local kiosk user. Defined here (not in common/users.nix) so it
  # exists only on the cabinet. Autologin is wired by the arcade profile.
  users.groups.arcade.gid = 2005;
  users.users.arcade = {
    isNormalUser = true;
    uid = 2005;
    group = "arcade";
    description = "arcade";
    extraGroups = ["audio" "video"];
    shell = pkgs.zsh;
  };

  home-manager.users.arcade = import ../../../home/users/arcade.nix;

  # Before changing this value read the documentation for this option
  # (man configuration.nix or https://nixos.org/nixos/options.html).
  system.stateVersion = "26.11";

  # Pull NixOS updates automatically from CI via cachix + GitHub Pages.
  # Create .autodeploy-skip/arcade to pause without editing this file.
  system.autoDeploy.enable = true;
}
```

- [ ] **Step 3: Create the `arcade` user config**

The host maps `home-manager.users.arcade` to `home/users/arcade.nix`. Create it, importing the arcade role (which itself pulls in `cli`).

Create `home/users/arcade.nix`:

```nix
# /home/users/arcade.nix
{...}: {
  imports = [
    ../roles/arcade.nix
  ];

  home = {
    username = "arcade";
    homeDirectory = "/home/arcade";

    shell.enableZshIntegration = true;

    packages = [];
  };
}
```

- [ ] **Step 4: Track all three new files**

Run: `jj file track nixos/hosts/arcade/hardware-configuration.nix nixos/hosts/arcade/configuration.nix home/users/arcade.nix`
Expected: no error. (The flake and CI auto-discover the host from the directory name — no flake.nix edit needed. See ADR-0003.)

- [ ] **Step 5: Format, then build the whole host end-to-end**

Run: `just fmt && just build arcade 2>&1 | tail -30`
Expected: the build **succeeds**. This is the first full evaluation of the arcade profile + role + host together. If it fails on a libretro core attribute name, run `nix search nixpkgs libretro` and correct the name in `home/roles/arcade.nix` (Task 4), then rebuild. If it fails because `retroarch.withCores` is unavailable, check the exact wrapper name with `nix eval nixpkgs#retroarch.withCores --apply builtins.typeOf` and adjust.

- [ ] **Step 6: Lint and commit**

Run: `just lint`
Expected: clean.

```bash
jj commit -m "feat(nixos): add arcade cabinet host

Auto-discovered arcade host wiring base + the arcade profile, with a
machine-local arcade user (defined in-host, not common/users.nix) mapped
to the arcade home role. Zero secrets. Placeholder hardware-configuration
to be replaced at bootstrap. stateVersion 26.11."
```

---

## Task 6: Final full-flake verification

Confirm the whole flake still checks out with all changes in place — every existing host plus the new arcade host — and that formatting/lint are clean fleet-wide.

**Files:** none (verification only).

- [ ] **Step 1: Full flake check**

Run: `just precommit 2>&1 | tail -20`
Expected: lint passes and `nix flake check` passes (this evaluates every `nixosConfigurations` entry, including `arcade`, and enforces alejandra formatting). If `nix flake check` tries to *build* every host and the arcade placeholder hardware causes a build (not eval) failure, note it — eval must pass; a build failure on the placeholder root filesystem is expected and acceptable until real hardware config is in place. In that case, verify eval-only with: `nix eval ".#nixosConfigurations.arcade.config.system.build.toplevel.drvPath"` and expect a `.drv` path to be printed.

- [ ] **Step 2: Confirm the arcade user is absent from other hosts**

Prove the machine-local user didn't leak fleet-wide.

Run: `nix eval ".#nixosConfigurations.wendigo.config.users.users.arcade" 2>&1 | tail -3`
Expected: an error / attribute-missing (there is no `arcade` user on `wendigo`) — confirming the user is host-local. Then: `nix eval --json ".#nixosConfigurations.arcade.config.users.users.arcade.name"` — expected: `"arcade"`.

- [ ] **Step 3: Final commit if any formatting changed**

Run: `just fmt`
Expected: no changes (already clean). If anything changed:

```bash
jj commit -m "chore: fmt after arcade cabinet addition"
```

---

## Post-plan: bootstrap steps (performed by the user at the physical machine, not part of this plan)

These are documented here so the handoff is complete. They happen when you install NixOS on the cabinet:

1. Boot the installer ISO (`just iso` builds it — see ADR-0007).
2. Run `nixos-bootstrap` on the live ISO to partition, generate the real `hardware-configuration.nix` and the host key, and save them to the artifact dir.
3. Transfer the generated `hardware-configuration.nix` back into `nixos/hosts/arcade/`, replacing the placeholder; `jj file track` it if needed and commit.
4. Commit the host pubkey to `nixos/hosts/arcade/ssh_host_ed25519_key.pub` (for known-hosts; no agenix recipient needed since the cabinet has zero secrets).
5. Deploy. Because the cabinet has no keyboard once running, prefer letting auto-deploy pull, or run the initial `switch` from the installer per the bootstrap SOP.
6. Drop ROM files into `/home/arcade/roms/<system>/` out of band (scp/Tailscale) — they are not in the repo (ADR-0010).

---

## Self-Review Notes

- **Spec coverage:** cli split (T1), ssh-hardened extraction (T2), arcade profile: graphics/audio/autologin/startx/ssh (T3), arcade role: attract-mode/RetroArch+5 cores/MAME/matchbox/.xinitrc/startx-guard (T4), host + machine-local user + autodeploy + zero secrets (T5), fleet verification (T6). All design decisions from the grilling session are covered.
- **Behavior-preservation:** T1 and T2 both diff store closures against a pre-change baseline to prove existing hosts are unchanged — the key risk of the two refactors.
- **Placeholder hardware config:** explicitly flagged as a stub to be replaced at bootstrap; T6 accounts for the possibility that `nix flake check` build-vs-eval behavior differs on it.
- **Uncertain nixpkgs attr names** (libretro cores, `retroarch.withCores`): each has an inline recovery command rather than being left as a silent TODO.
