#!/usr/bin/env bash
# nixos-bootstrap: Interactive installer for adding a new NixOS host to the flake.
#
# What this script does:
#   1. Checks /mnt is mounted (with guided setup if not)
#   2. Prompts for hostname
#   3. Generates hardware-configuration.nix
#   4. Pre-generates the host SSH keypair (for SSH access to the installed system)
#   5. Clones the nix-config repo if network is available
#   6. Writes hardware-configuration.nix and a template configuration.nix
#      directly into the cloned repo
#   7. Prints a single command block to paste on an existing machine (wendigo/kushtaka)
#      to commit and push
#   8. Waits for confirmation, then runs nixos-install
#
# All required tools are injected via runtimeInputs in configuration.nix —
# this script does not rely on ambient PATH entries.

set -euo pipefail

FLAKE_REPO="github:asphaltbuffet/nix-config"
FLAKE_GIT="https://github.com/asphaltbuffet/nix-config"
REPO_PATH="/etc/nix-config"        # read-only ISO snapshot
WORK_REPO="/home/nixos/nix-config" # writable clone (if network available)

# ─────────────────────────────────────────────────────────────────────────────
# UI helpers
# ─────────────────────────────────────────────────────────────────────────────

header() {
  echo ""
  echo "=========================================="
  echo "  $*"
  echo "=========================================="
  echo ""
}

section() {
  echo ""
  echo "--- $* ---"
}

confirm() {
  # Usage: confirm "Question?" && do_thing
  local prompt="$1"
  printf "%s [y/N] " "$prompt"
  read -r answer
  [[ "${answer,,}" == "y" ]]
}

# ─────────────────────────────────────────────────────────────────────────────
# Step 0: check /mnt
# ─────────────────────────────────────────────────────────────────────────────

check_or_guide_mount() {
  if mountpoint -q /mnt; then
    echo "✓ /mnt is mounted."
    return
  fi

  # Detect the most likely target disk: first non-removable, non-loop disk
  # excluding CD-ROM (sr*). NVMe uses p1/p2 suffixes; sda/vda use 1/2 directly.
  local disk part_suffix
  disk=$(lsblk -dnpo NAME,TYPE,RM | awk '$2=="disk" && $3=="0" {print $1}' | grep -v '^/dev/sr' | head -1)
  if [[ -z "$disk" ]]; then
    disk="/dev/sda"  # fallback
  fi
  if [[ "$disk" == *nvme* ]]; then
    part_suffix="p"
  else
    part_suffix=""
  fi

  echo ""
  echo "  /mnt is not mounted. Disk partitioning is required before bootstrapping."
  echo ""
  echo "  Detected disk: $disk  (verify with: lsblk)"
  echo ""
  echo "    parted ${disk} -- mklabel gpt"
  echo "    parted ${disk} -- mkpart root ext4 512MB -8GB"
  echo "    parted ${disk} -- mkpart swap linux-swap -8GB 100%"
  echo "    parted ${disk} -- mkpart ESP fat32 1MB 512MB"
  echo "    parted ${disk} -- set 3 esp on"
  echo "    mkfs.ext4 -L nixos ${disk}${part_suffix}1"
  echo "    mkfs.fat -F 32 -n boot ${disk}${part_suffix}2"
  echo "    mount /dev/disk/by-label/nixos /mnt"
  echo "    mkdir -p /mnt/boot"
  echo "    mount /dev/disk/by-label/boot /mnt/boot"
  echo ""
  echo "  See: https://nixos.org/manual/nixos/stable/#sec-installation-manual-partitioning"
  echo ""

  if confirm "Have you partitioned and mounted /mnt and are ready to continue?"; then
    if ! mountpoint -q /mnt; then
      echo "ERROR: /mnt is still not a mountpoint. Please mount it and re-run nixos-bootstrap."
      exit 1
    fi
    echo "✓ /mnt is now mounted."
  else
    echo "Exiting. Re-run nixos-bootstrap when /mnt is ready."
    exit 0
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Step 1: hostname
# ─────────────────────────────────────────────────────────────────────────────

get_hostname() {
  printf "Enter the hostname for the new machine: "
  read -r HOSTNAME
  if [[ -z "$HOSTNAME" ]]; then
    echo "ERROR: hostname cannot be empty"
    exit 1
  fi
  echo "Hostname: $HOSTNAME"
}

# ─────────────────────────────────────────────────────────────────────────────
# Step 2: hardware config
# ─────────────────────────────────────────────────────────────────────────────

generate_hardware_config() {
  section "Generating hardware configuration"
  nixos-generate-config --root /mnt
  echo "Generated: /mnt/etc/nixos/hardware-configuration.nix"
}

# ─────────────────────────────────────────────────────────────────────────────
# Step 3: host SSH key
# ─────────────────────────────────────────────────────────────────────────────

generate_host_key() {
  section "Host SSH key"
  local key_path="/mnt/etc/ssh/ssh_host_ed25519_key"
  local pub_path="${key_path}.pub"

  mkdir -p /mnt/etc/ssh
  chmod 700 /mnt/etc/ssh

  if [[ -f "$pub_path" ]]; then
    echo "Host key already exists at $pub_path"
  else
    echo "Generating host SSH key for the installed system..."
    ssh-keygen -t ed25519 -N "" -f "$key_path" -C "root@${HOSTNAME}"
    chmod 600 "$key_path"
    chmod 644 "$pub_path"
  fi

  HOST_PUBKEY=$(cat "$pub_path")
  echo "Host public key:"
  echo "  $HOST_PUBKEY"
}

# ─────────────────────────────────────────────────────────────────────────────
# Step 4: clone repo or use ISO snapshot
# ─────────────────────────────────────────────────────────────────────────────

setup_repo() {
  section "Repo setup"

  if [[ -d "$WORK_REPO/.git" ]]; then
    echo "Writable repo already present at $WORK_REPO"
    REPO_WRITABLE=true
    return
  fi

  # Try network clone
  if curl -sf --max-time 5 https://github.com >/dev/null 2>&1; then
    echo "Network available — cloning $FLAKE_GIT ..."
    git clone "$FLAKE_GIT" "$WORK_REPO"
    REPO_WRITABLE=true
    echo "Cloned to: $WORK_REPO"
  else
    echo "No network — will use read-only ISO snapshot at $REPO_PATH for reference."
    echo "Files will be saved to /home/nixos/bootstrap-${HOSTNAME}/ for manual transfer."
    REPO_WRITABLE=false
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Step 5: write host files into repo (or save to artifact dir)
# ─────────────────────────────────────────────────────────────────────────────

write_nixos_version() {
  nixos-version | cut -d. -f1-2 2>/dev/null || echo "25.05"
}

write_host_files() {
  local version
  version=$(write_nixos_version)

  local hw_src="/mnt/etc/nixos/hardware-configuration.nix"
  local artifact_dir="/home/nixos/bootstrap-${HOSTNAME}"
  mkdir -p "$artifact_dir"

  # Always save artifacts for backup / manual fallback
  cp "$hw_src" "$artifact_dir/hardware-configuration.nix"
  echo "$HOST_PUBKEY" >"$artifact_dir/ssh_host_ed25519_key.pub"

  if [[ "$REPO_WRITABLE" == "true" ]]; then
    section "Writing host files into repo"
    local host_dir="${WORK_REPO}/nixos/hosts/${HOSTNAME}"
    mkdir -p "$host_dir"

    cp "$hw_src" "${host_dir}/hardware-configuration.nix"
    echo "  Wrote: nixos/hosts/${HOSTNAME}/hardware-configuration.nix"

    cat >"${host_dir}/configuration.nix" <<CONF
{...}: {
  imports = [
    ./hardware-configuration.nix
    ../../common/users.nix
    ../../profiles/base.nix
    ../../profiles/laptop
    # Uncomment for ThinkPad T14:
    # ../../profiles/laptop/t14.nix
    # Uncomment for Microsoft Surface (configures WiFi, touch, pen):
    # inputs.nixos-hardware.nixosModules.microsoft-surface-common
  ];

  networking.hostName = "${HOSTNAME}";
  system.stateVersion = "${version}";
}
CONF
    echo "  Wrote: nixos/hosts/${HOSTNAME}/configuration.nix"
    echo "  Review and edit that file if you need non-default imports."
  else
    section "Saving artifacts (no writable repo)"
    cat >"$artifact_dir/configuration.nix.template" <<CONF
{...}: {
  imports = [
    ./hardware-configuration.nix
    ../../common/users.nix
    ../../profiles/base.nix
    ../../profiles/laptop
    # Uncomment for ThinkPad T14:
    # ../../profiles/laptop/t14.nix
    # Uncomment for Microsoft Surface (configures WiFi, touch, pen):
    # inputs.nixos-hardware.nixosModules.microsoft-surface-common
  ];

  networking.hostName = "${HOSTNAME}";
  system.stateVersion = "${version}";
}
CONF
    echo "  Saved artifacts to: $artifact_dir"
    echo "  hardware-configuration.nix"
    echo "  ssh_host_ed25519_key.pub"
    echo "  configuration.nix.template"
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Step 6: print the "paste this on an existing machine" block
# ─────────────────────────────────────────────────────────────────────────────

build_instructions() {
  local live_ip
  live_ip=$(ip -4 addr show scope global | awk '/inet/{print $2}' | cut -d/ -f1 | head -1)
  local scp_block=""
  if [[ "$REPO_WRITABLE" == "true" ]]; then
    scp_block="  # Pull the new host files and pubkey from this live machine
  # (check connectivity first: ssh nixos@${live_ip} 'echo ok')
  mkdir -p nixos/hosts/${HOSTNAME}
  scp nixos@${live_ip}:/home/nixos/nix-config/nixos/hosts/${HOSTNAME}/hardware-configuration.nix \\
      nixos/hosts/${HOSTNAME}/hardware-configuration.nix
  scp nixos@${live_ip}:/home/nixos/nix-config/nixos/hosts/${HOSTNAME}/configuration.nix \\
      nixos/hosts/${HOSTNAME}/configuration.nix
  scp nixos@${live_ip}:/home/nixos/bootstrap-${HOSTNAME}/ssh_host_ed25519_key.pub \\
      nixos/hosts/${HOSTNAME}/ssh_host_ed25519_key.pub"
  else
    scp_block="  # Copy files from USB/transfer
  mkdir -p nixos/hosts/${HOSTNAME}
  cp /path/to/hardware-configuration.nix nixos/hosts/${HOSTNAME}/hardware-configuration.nix
  cp /path/to/configuration.nix.template  nixos/hosts/${HOSTNAME}/configuration.nix
  cp /path/to/ssh_host_ed25519_key.pub    nixos/hosts/${HOSTNAME}/ssh_host_ed25519_key.pub"
  fi

  cat <<INSTRUCTIONS
==========================================
  NEXT STEPS — use this on existing host
==========================================

  cd ~/nix-config   # or wherever your checkout is

${scp_block}

  # Review/edit the host configuration if needed
  \$EDITOR nixos/hosts/${HOSTNAME}/configuration.nix

  # Track and commit (jj — do NOT use git add)
  jj file track nixos/hosts/${HOSTNAME}/configuration.nix
  jj file track nixos/hosts/${HOSTNAME}/hardware-configuration.nix
  jj commit -m 'feat: add host ${HOSTNAME}'
  jj git push -c @-

==========================================
  BACK ON THIS LIVE ISO — after the push completes
==========================================

  # Verify the flake sees the new host (optional sanity check)
  nix flake show ${FLAKE_REPO}

  # Install
  nixos-install --flake ${FLAKE_REPO}#${HOSTNAME}

  # Reboot
  reboot

==========================================
  POST-INSTALL (first boot)
==========================================

  # Authenticate Tailscale (one-time — state persists across reboots thereafter)
  sudo tailscale up --auth-key <your-auth-key>

  # Sign in to 1Password
  op signin

  # API keys (GORELEASER_KEY, ANTHROPIC_API_KEY) inject automatically
  # in new shells once 1Password is unlocked.

==========================================
  MISC NOTES
==========================================

Surface:
  - Secure Boot must be disabled to boot this ISO.
  - Surface Pro 3/4 may need a USB-A adapter for USB boot.
  - If WiFi/touch/pen doesn't work post-install, add the nixos-hardware
    Surface module (see configuration.nix imports) and rebuild.

INSTRUCTIONS
}

print_instructions() {
  local out_dir="/home/nixos/bootstrap-${HOSTNAME}"
  local instructions_file="${out_dir}/INSTRUCTIONS.txt"

  build_instructions | tee "$instructions_file" >/dev/null
  echo ""
  echo "Instructions saved to: $instructions_file"
  echo "(Re-read anytime with: less $instructions_file)"
  echo ""

  build_instructions | less --quit-if-one-screen --RAW-CONTROL-CHARS
}

# ─────────────────────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────────────────────

main() {
  header "NixOS Bootstrap Helper"
  check_or_guide_mount
  get_hostname
  generate_hardware_config
  generate_host_key
  setup_repo
  write_host_files
  print_instructions
}

main "$@"
