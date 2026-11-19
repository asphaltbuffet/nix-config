# GUI roles are gated on a `host.workstation` fact

Home-manager roles are imported per user, and `nixos/common/users.nix` attaches every user to every host that imports it, so a user's GUI roles used to land on bunyip and the arcade cabinet too. Graphical applications now install only on a **Workstation** (CONTEXT.md). The signal is a new host fact, `host.workstation` in `nixos/common/host.nix`, which defaults to `false` and is set to `true` explicitly in each workstation's `configuration.nix` (wendigo, kushtaka, snallygaster). Roles read it through `osConfig`.

## Decisions

- **The gate lives inside each role, not in the user file.** The `desktop` role imports `cli.nix` unconditionally and wraps only its desktop applications in the gate. The `player` and `maker` roles are gated whole. `osConfig` is a home-manager specialArg, so it can be read while `imports` are resolved (`imports = lib.optionals osConfig.host.workstation [ … ]`) without infinite recursion.
- **`admin` and `dev` stay ungated.** They are CLI tooling (nmap, lnav, jj, nvim, claude) that is useful when SSHed into bunyip.
- **The fact is set per host, not by `profiles/laptop/`.** Each host's `configuration.nix` states what it is, the same way `host.alwaysOn` is set.

## Considered Options

- **Reuse `osConfig.services.desktopManager.plasma6.enable`**, already read by the `ssh`, `zsh` and `1password` modules. Rejected for role gating: it stands in for "is a workstation" and would break if a workstation ever ran another desktop environment. Those three modules keep it, because they configure KDE-specific behaviour.
- **Set `host.workstation` in `profiles/laptop/default.nix`.** Rejected in favour of an explicit line per host.
- **Split imports in `home/users/<name>.nix`** by `osConfig`. Rejected: every user file would repeat the condition, and a new user would get GUI apps on servers by default.
- **Gate by hostname** (`!= "bunyip"`). Rejected: it lists the exceptions instead of naming the property, so every new non-workstation host would need an edit.

## Consequences

- A new laptop or desktop host that does not set `host.workstation = true` boots with no browser, password manager or other desktop apps. This fails safe, but it is easy to miss when onboarding a host.
- `jsquats` and `sukey` lose their `desktop` and `player` apps on bunyip and arcade along with `grue`.
- Any future GUI role must apply the same gate.
