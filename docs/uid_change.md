# UID Change Procedure

Required to align NixOS UIDs with NAS UIDs for NFS v4.1 auth.
NFS uses numeric UIDs — they must match on both sides for file ownership to work correctly.

## UID/GID Mapping

GIDs are changed to match UIDs to avoid future collision when TOS auto-assigns new users.

| NixOS user | NAS user | Old UID | Old GID | New UID | New GID |
|------------|----------|---------|---------|---------|---------|
| grue       | ben      | 1001    | 1001    | 2001    | 2001    |
| jsquats    | jasper   | 1003    | 1003    | 2003    | 2003    |
| sukey      | sarah    | 1004    | 1004    | 2004    | 2004    |

---

## Step 1: Remap UIDs on the NAS

Run as `chief` on the NAS (chief is uid=0, no sudo needed).
Note: `fd` is not available on TOS — use `find` here.

If a user has an active session, kill it first:
```bash
loginctl terminate-user <username>
# If it respawns, kill the systemd user process directly:
kill -9 $(ps aux | awk '/^<username>/ {print $2}')
```

```bash
# ben: uid 1004->2001, gid 1004->2001
usermod -u 2001 ben
groupmod -g 2001 ben
usermod -g 2001 ben
find /Volume1/homes/ben -user 1004 -exec chown -h 2001 {} \;
find /Volume1/homes/ben -group 1004 -exec chown -h :2001 {} \;

# jasper: uid 1006->2003, gid 1006->2003
usermod -u 2003 jasper
groupmod -g 2003 jasper
usermod -g 2003 jasper
find /Volume1/homes/jasper -user 1006 -exec chown -h 2003 {} \;
find /Volume1/homes/jasper -group 1006 -exec chown -h :2003 {} \;

# sarah: uid 1005->2004, gid 1005->2004
usermod -u 2004 sarah
groupmod -g 2004 sarah
usermod -g 2004 sarah
find /Volume1/homes/sarah -user 1005 -exec chown -h 2004 {} \;
find /Volume1/homes/sarah -group 1005 -exec chown -h :2004 {} \;

# Verify
getent passwd | awk -F: '$3 >= 1000 && $3 < 9000 {print $1, $3}' | sort -k2 -n
id ben && id jasper && id sarah
```

---

## Step 2: Switch NixOS config

UIDs and GIDs are pinned in `nixos/common/users.nix`. Running `just switch` will update
GIDs in `/etc/group` but **will NOT update UIDs** for currently logged-in users — NixOS
refuses to change UIDs of active users. A reboot is required.

```bash
just switch
reboot
```

---

## Step 3: Re-chown home directories on NixOS

Must be done as root after rebooting. Log in as root (e.g. via `sudo -i` or root TTY)
before logging in as any of the affected users.

Use `find` rather than `fd` — `fd` skips certain files (e.g. hidden files, files in
restricted dirs) that must also be re-chowned.

```bash
# grue: uid+gid 1001 -> 2001
find /home/grue -xdev \( -user 1001 -exec chown -h 2001 {} \; -o -group 1001 -exec chown -h :2001 {} \; \)

# jsquats: uid+gid 1003 -> 2003
find /home/jsquats -xdev \( -user 1003 -exec chown -h 2003 {} \; -o -group 1003 -exec chown -h :2003 {} \; \)

# sukey: uid+gid 1004 -> 2004
find /home/sukey -xdev \( -user 1004 -exec chown -h 2004 {} \; -o -group 1004 -exec chown -h :2004 {} \; \)
```

The `-xdev` flag prevents crossing filesystem boundaries, avoiding accidental re-chown
of files on NFS mounts or other partitions.

---

## Step 4: Verify

```bash
# Check NixOS users have correct UIDs and GIDs
id grue && id jsquats && id sukey

# Check no files remain with old UIDs/GIDs in home dirs
find /home/grue /home/jsquats /home/sukey -xdev \( -user 1001 -o -user 1003 -o -user 1004 -o -group 1001 -o -group 1003 -o -group 1004 \) | head -20
```

The second command should return no output if re-chown completed successfully.
