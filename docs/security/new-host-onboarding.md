# New Host Onboarding

## NixOS Hosts (managed by this flake)

### Prerequisites
- Access to this repo on an existing managed machine

### Steps

**1. Install NixOS** using the installer ISO:
```bash
just iso    # build the ISO
just vm     # test it in QEMU (optional)
# Flash with: dd if=result/iso/*.iso of=/dev/sdX bs=4M
```
The installer generates `/etc/ssh/ssh_host_ed25519_key` automatically.

**2. Get the new host's public key** (run on the new machine):
```bash
cat /etc/ssh/ssh_host_ed25519_key.pub
```

**3. Add the host to this repo** (run on an existing managed machine):
```bash
just ssh-add-host <hostname> "<pubkey from step 2>"
# Follow the printed instructions to edit secrets/secrets.nix
just secret-rekey
jj commit -m "feat: add <hostname> to agenix recipients"
```

**4. Deploy to the new host:**
```bash
just switch <hostname>
```
agenix decrypts secrets using the host's system key (no user key needed).

**5. Install 1Password and enable SSH agent:**
- Download from https://1password.com/downloads/linux/
- Sign in → Settings → Developer → Enable SSH Agent
- Your `grue-main` key appears automatically (synced from vault)

**6. Verify:**
```bash
just ssh-verify
```

---

## Windows Hosts (non-managed)

**1. Install 1Password for Windows** from https://1password.com/downloads/windows/

**2. Enable the SSH agent:**
- Settings → Developer → Use the SSH agent
- This creates a named pipe: `\\.\pipe\openssh-ssh-agent`

**3. Configure OpenSSH client** (Windows 10/11 has OpenSSH built in):

Edit or create `%USERPROFILE%\.ssh\config`:
```
Host *
    IdentityAgent \\.\pipe\openssh-ssh-agent
    ServerAliveInterval 60
    ServerAliveCountMax 3
```

**4. Add your public key to any servers** you need to access:
- In 1Password, open the `grue-main` item and copy the public key
- Paste into `~/.ssh/authorized_keys` on the target server

**5. Configure git signing** (optional — if using git on this machine):
```bash
git config --global gpg.format ssh
git config --global user.signingkey "ssh-ed25519 AAAA..."  # your public key
git config --global commit.gpgsign true
```

---

## Non-NixOS Linux Hosts (non-managed)

**1. Install 1Password for Linux** from https://1password.com/downloads/linux/

**2. Enable the SSH agent:**
- Settings → Developer → Use the SSH agent
- Socket path: `~/.1password/agent.sock`

**3. Configure SSH client:**

Edit or create `~/.ssh/config`:
```
Host *
    IdentityAgent ~/.1password/agent.sock
    ServerAliveInterval 60
    ServerAliveCountMax 3
```

**4. Add your public key to servers** you need to access (same as Windows step 4).

**5. Configure git signing** (same as Windows step 5).

**6. Verify:**
```bash
SSH_AUTH_SOCK=~/.1password/agent.sock ssh-add -l  # should show your key
ssh -T git@github.com                              # should authenticate
```
