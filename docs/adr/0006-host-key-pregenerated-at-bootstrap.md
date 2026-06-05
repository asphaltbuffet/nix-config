# Host SSH key is pre-generated during bootstrap, not on first boot

`nixos-bootstrap` generates the host's ed25519 SSH keypair at `/mnt/etc/ssh/ssh_host_ed25519_key` before running `nixos-install`. The public key is saved to the artifact dir and committed to the repo at `nixos/hosts/<name>/ssh_host_ed25519_key.pub`.

If the key were left to sshd to generate on first boot, the host's public key would be unknown until after the first boot — meaning it could not be added to `secrets/secrets.nix` as an agenix recipient until after install, requiring a second `just rekey` + push + switch cycle. Pre-generating breaks this chicken-and-egg: the host key is known before install, so agenix secrets can be rekeyed and committed in the same PR that adds the host, and the installed system can decrypt its secrets on the very first boot.
