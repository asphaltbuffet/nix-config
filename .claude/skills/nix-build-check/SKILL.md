---
name: nix-build-check
description: Build and optionally activate NixOS config for a host. Use when the user wants to build, test, or switch their NixOS configuration.
disable-model-invocation: true
---

# NixOS Build & Check

Guide the user through the NixOS build/activate workflow:

1. Always run `just fmt` first to ensure formatting passes
2. Run `just build [host]` to validate the config builds cleanly
3. Run `just diff [host]` to preview what will change before activating
4. Optionally run `just test [host]` to activate without setting boot default
5. Optionally run `just switch [host]` to activate and set as boot default

Available hosts: wendigo, kushtaka, snallygaster. Default host is the current machine (`hostname`).

Ask the user which host and which action (build/test/switch) they want, then run the appropriate `just` command.
