# attract-mode gets an interface module, written to be upstreamable

attract-mode's configuration moves from the arcade role into `home/modules/attract-mode/`, declaring a `programs.attract-mode` option interface. Unlike the repo's other 27 modules — thin config-setters wrapping option interfaces nixpkgs already provides — this one declares its own options, because home-manager has no upstream module for attract-mode. It is written to home-manager's conventions so it can be contributed upstream once proven on the cabinet; the option path is identical either way, so contributing later is a file deletion.

The point is separating "what attract-mode can express" from "what this cabinet wants". Configuration living in a role can only ever describe that role's machine.

## Considered Options

- **Move it to a module without declaring options**, matching the other 27 superficially — rejected because a zero-knob module for a tool with no upstream interface is the role's code in a different file, enabling no reuse.
- **Upstream first** — rejected as sequencing: it blocks the cabinet on someone else's review queue, and an interface that has never run on hardware is worse for reviewers than a proven one.

## Consequences

- Three boundaries that the role had blurred are now enforced by the module's types: emulator definitions carry only attract-mode fields (HyperSpin `mediaSystem` metadata moves to a separate mapping); displays are independent of emulators rather than generated 1:1; artwork paths are absolute rather than derived from a hardcoded `/mnt/roms/media` convention.
- The module must not assume this cabinet — no cosmo layout names, no `/mnt/roms`, no MAME special-casing. Anything cabinet-specific stays in the arcade role.
- Scope is limited to what the cabinet uses; filters, screensaver, and intro parameters are unimplemented, with option types shaped so they can be added without breaking changes.
- Romlists stay out of scope per ADR-0010. The module ships a wrapper running `attract --build-romlist`, but never during activation: `/mnt/roms` is `nofail`, and caching empty romlists from an absent drive is worse than generating none.
