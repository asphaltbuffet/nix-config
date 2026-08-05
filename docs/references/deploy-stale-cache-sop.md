# Deploying appeared to succeed but nothing changed

Three independent caches sit between a commit and a running host. Each one, when
stale, reports success for work it did not do. All three were hit in a single
session diagnosing an empty secret on the arcade cabinet, so check them in this
order before suspecting the config.

## 1. Nix flake registry TTL (`nixos-rebuild --flake github:...`)

`sudo nixos-rebuild switch --flake github:owner/repo#host` resolves the branch
through Nix's registry cache, governed by `tarball-ttl` (default 1 hour). Inside
that window Nix reuses the previously resolved revision, evaluates the identical
closure, finds nothing to do, and exits 0 — **no new generation, no error, no
diagnostic**. A reboot afterwards boots the same old generation.

Symptom: `nixos-rebuild list-generations` shows the newest generation predating
the commit you are trying to deploy.

Fix — force re-resolution, or pin the revision so it cannot go stale:

```bash
sudo nixos-rebuild switch --refresh --flake github:owner/repo#host
sudo nixos-rebuild switch --flake github:owner/repo/<full-sha>#host
```

On an autodeploy host, prefer `sudo systemctl start nixos-autodeploy.service` —
it fetches by exact store path, so there is no branch resolution to go stale.

## 2. Published closure lag (autodeploy)

`nixos-autodeploy` compares the running system against the **published** store
path, not against the repo. If CI has not finished building the commit, the host
logs `System is up to date` and that is accurate — the upstream it tracks really
has not moved. Rebooting does not help; the closure has to be published first.

Symptom: autodeploy logs `Upstream:` and `Current:` as the same path while the
repo is ahead. Check with `gh run list --limit 5` and `just autodeploy-status
<host>`; builds here take 11–13 minutes.

## 3. attract-mode scraper cache (0-byte poisoning)

`get_tgdb_platform_list` (`scraper_gamesdb.cpp`) calls `write_local_if_needed`
**outside** the success branch, so a failed API call writes a 0-byte
`platforms.txt` and returns true. Every later run then short-circuits in
`load_from_local`, which checks only that the file *exists* — never that it
parsed. One transient failure poisons the cache permanently.

Symptom: `! Error: None of the configured system identifier(s) are recognized by
thegamesdb.net.` on `attract-build-romlists`, for the console systems only.
**MAME masks this**: `info_source listxml` falls back to a hardcoded "Arcade"
platform when the list is empty, so testing MAME alone shows no problem.

Fix — repair the credential *first*, then clear the caches. Clearing first just
recreates them empty:

```bash
wc -c /run/agenix/arcade/thegamesdbKey   # must be non-zero before continuing
rm ~/.attract/scraper/thegamesdb.net/{platforms,genres,publishers}.txt
attract-build-romlists                    # success: "Wrote file: .../platforms.txt"
```

## Bonus: an empty agenix secret is invisible

An `.age` file encrypting an empty string decrypts *successfully* — correct path,
owner and mode, zero bytes. Nothing in agenix or the activation log flags it; the
failure surfaces only in the consuming application, arbitrarily far away.

- `test -s <path>` distinguishes it; `ls` alone does not.
- Do **not** run the check under `sudo` as a non-wheel user — sudo fails for an
  unrelated reason and looks identical to the secret being absent.
- Cross-check against another secret sharing the same host key (e.g.
  `hcPingKey`). If that one has content, decryption is fine and the ciphertext
  itself is empty.
- A ~322-byte `.age` file with two recipients is an encrypted *empty* payload;
  real content shows up as a larger payload after the `--- ` header line.

Repair with `agenix -e secrets/<path>.age` (there is no `just` recipe — `just
rekey` only re-encrypts existing content, so it will faithfully re-encrypt
nothing).
