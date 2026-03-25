# SSH Key Management

## Architecture

This repo uses a hybrid SSH key model:

| Layer | Tool | Where key lives |
|-------|------|-----------------|
| Interactive SSH auth | 1Password SSH agent | 1P vault only |
| Git/jj commit signing | 1Password SSH agent | 1P vault only |
| API key injection | 1Password CLI (`op inject`) | 1P vault only |

Private key material for user identity **never exists as a file on disk**.
The 1Password agent signs operations without exposing key material.

## Daily Use

### SSH to a server
```bash
ssh user@server
# 1Password prompts for biometric/password approval
```

### See git/jj commit signatures
```bash
jj log -r @ --template 'if(signature, "signed", "unsigned") ++ "\n"'
```

### Add your key to a new server
```bash
just ssh-pubkey          # prints your public key
ssh-copy-id user@server  # or paste manually into authorized_keys
```

## Key Rotation
```bash
just ssh-rotate
```
Follow the guided steps. The old key stays valid until you remove it from servers and GitHub.

## Verifying Your Setup
```bash
just ssh-verify
```

## Adding a New NixOS Host

Use the ISO bootstrap process — run `nixos-bootstrap` on the live installer,
then follow the printed instructions. See
[`docs/security/new-host-onboarding.md`](new-host-onboarding.md) for the
full walkthrough.

## Security Notes

- Only ed25519 keys are used (RSA and ECDSA host keys are disabled in `nixos/profiles/base.nix`)
- Password authentication is disabled on all hosts (SSH keys only)
- Root login is disabled

