# SSH Key Management

## Architecture

This repo uses a hybrid SSH key model:

| Layer | Tool | Where key lives |
|-------|------|-----------------|
| Interactive SSH auth | 1Password SSH agent | 1P vault only |
| Git/jj commit signing | 1Password SSH agent | 1P vault only |
| agenix decryption | Host system key | `/etc/ssh/ssh_host_ed25519_key` |

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

## Adding a New NixOS Host to agenix

```bash
# 1. On the new host, get its system SSH public key:
cat /etc/ssh/ssh_host_ed25519_key.pub

# 2. In this repo, follow the guided instructions:
just ssh-add-host <hostname> "<pubkey from step 1>"

# 3. Re-encrypt and deploy:
just secret-rekey
just switch
```

## Security Notes

- Only ed25519 keys are used (RSA and ECDSA host keys are disabled in `nixos/profiles/base.nix`)
- Password authentication is disabled on all hosts (SSH keys only)
- Root login is disabled
- All secrets are encrypted to both user keys AND host keys, so secrets remain
  accessible via the host key even during user key rotation
