#!/usr/bin/env bash
# nixos-bootstrap: Captures hardware config and host SSH key for a new NixOS host,
# then prints the steps needed to add it to the nix-config flake.

set -euo pipefail

FLAKE_REPO="github:asphaltbuffet/nix-config"
FLAKE_GIT="https://github.com/asphaltbuffet/nix-config"

print_header() {
  echo ""
  echo "=========================================="
  echo "  NixOS Bootstrap Helper"
  echo "=========================================="
  echo ""
}

get_hostname() {
  printf "Enter the hostname for the new machine: "
  read -r HOSTNAME
  if [[ -z "$HOSTNAME" ]]; then
    echo "ERROR: hostname cannot be empty"
    exit 1
  fi
  echo "Hostname: $HOSTNAME"
}

check_mounted() {
  if ! mountpoint -q /mnt; then
    echo ""
    echo "ERROR: /mnt is not a mountpoint."
    echo ""
    echo "Partition your disk and mount it first, for example:"
    echo "  parted /dev/nvme0n1 -- mklabel gpt"
    echo "  parted /dev/nvme0n1 -- mkpart root ext4 512MB 100%"
    echo "  parted /dev/nvme0n1 -- mkpart ESP fat32 1MB 512MB"
    echo "  parted /dev/nvme0n1 -- set 2 esp on"
    echo "  mkfs.ext4 -L nixos /dev/nvme0n1p1"
    echo "  mkfs.fat -F 32 -n boot /dev/nvme0n1p2"
    echo "  mount /dev/disk/by-label/nixos /mnt"
    echo "  mkdir -p /mnt/boot"
    echo "  mount /dev/disk/by-label/boot /mnt/boot"
    echo ""
    echo "See: https://nixos.org/manual/nixos/stable/#sec-installation-manual-partitioning"
    exit 1
  fi
}

generate_hardware_config() {
  echo ""
  echo "--- Generating hardware configuration ---"
  nixos-generate-config --root /mnt
  echo ""
  echo "Generated: /mnt/etc/nixos/hardware-configuration.nix"
}

generate_host_key() {
  echo ""
  echo "--- Host SSH key ---"
  local key_path="/mnt/etc/ssh/ssh_host_ed25519_key"
  local pub_path="${key_path}.pub"

  mkdir -p /mnt/etc/ssh
  chmod 700 /mnt/etc/ssh

  if [[ -f "$pub_path" ]]; then
    echo "Host key already exists at $pub_path"
  else
    echo "Generating host key for installed system..."
    ssh-keygen -t ed25519 -N "" -f "$key_path" -C "root@${HOSTNAME}"
    chmod 600 "$key_path"
    chmod 644 "$pub_path"
  fi

  HOST_PUBKEY=$(cat "$pub_path")
  echo "Host public key:"
  echo "  $HOST_PUBKEY"
}

save_artifacts() {
  local out_dir="/root/bootstrap-${HOSTNAME}"
  mkdir -p "$out_dir"
  cp /mnt/etc/nixos/hardware-configuration.nix "$out_dir/"
  echo "$HOST_PUBKEY" >"$out_dir/ssh_host_ed25519_key.pub"
  echo ""
  echo "Artifacts saved to: $out_dir"
  echo "  hardware-configuration.nix"
  echo "  ssh_host_ed25519_key.pub"
  echo ""
  echo "Copy these files to your repo before rebooting."
}

print_nixos_version() {
  nixos-version | cut -d. -f1-2 2>/dev/null || echo "25.05"
}

print_instructions() {
  local version
  version=$(print_nixos_version)

  echo ""
  echo "=========================================="
  echo "  NEXT STEPS"
  echo "=========================================="
  echo ""
  echo "On a machine with access to the nix-config repo:"
  echo ""
  echo "  git clone $FLAKE_GIT && cd nix-config"
  echo "  # (or cd into an existing checkout)"
  echo ""
  echo "1. Create the host directory:"
  echo ""
  echo "   mkdir -p nixos/hosts/${HOSTNAME}"
  echo ""
  echo "2. Copy hardware-configuration.nix from /root/bootstrap-${HOSTNAME}/ to:"
  echo "   nixos/hosts/${HOSTNAME}/hardware-configuration.nix"
  echo ""
  echo "3. Create nixos/hosts/${HOSTNAME}/configuration.nix:"
  echo ""
  cat <<CONF
   { ... }: {
     imports = [
       ./hardware-configuration.nix
       ../../common/users.nix
       ../../profiles/base.nix
       # Uncomment for ThinkPad T14:
       # ../../profiles/laptop/t14.nix
       # Uncomment for Microsoft Surface (configures WiFi, touch, pen):
       # inputs.nixos-hardware.nixosModules.microsoft-surface-common
       # Uncomment for gaming:
       # ../../profiles/gaming.nix
     ];

     networking.hostName = "${HOSTNAME}";
     system.stateVersion = "${version}";
   }
CONF

  echo ""
  echo "4. Add the host public key to secrets/secrets.nix:"
  echo ""
  echo "   ${HOSTNAME} = \"${HOST_PUBKEY}\";"
  echo ""
  echo "   Then add \${${HOSTNAME}} to the systems list in that file."
  echo ""
  echo "5. Re-encrypt secrets (requires your agenix identity key):"
  echo ""
  echo "   just secret-rekey"
  echo ""
  echo "6. Track new files and commit (jj required — do NOT use git add):"
  echo ""
  echo "   jj file track nixos/hosts/${HOSTNAME}/configuration.nix"
  echo "   jj file track nixos/hosts/${HOSTNAME}/hardware-configuration.nix"
  echo "   jj commit -m 'feat: add host ${HOSTNAME}'"
  echo "   jj git push"
  echo ""
  echo "7. Install NixOS (from this live ISO, after pushing):"
  echo ""
  echo "   nixos-install --flake ${FLAKE_REPO}#${HOSTNAME}"
  echo ""
  echo "   Or with a local checkout mounted/cloned at /repo:"
  echo "   nixos-install --flake /repo#${HOSTNAME}"
  echo ""
  echo "   IMPORTANT: Do NOT wipe /mnt/etc/ssh/ before running nixos-install."
  echo "   The pre-generated host key must survive to the installed system so"
  echo "   agenix can decrypt secrets on first boot."
  echo ""
  echo "8. Reboot:"
  echo ""
  echo "   reboot"
  echo ""
  echo "=========================================="
  echo ""
  echo "Surface notes:"
  echo "  - If WiFi/touch/pen doesn't work after install, add the nixos-hardware"
  echo "    Surface module (see step 3 above) and rebuild."
  echo "  - Secure Boot must be disabled to boot this ISO."
  echo "  - Surface Pro 3/4 may need a USB-A adapter for USB boot."
  echo ""
}

main() {
  print_header
  get_hostname
  check_mounted
  generate_hardware_config
  generate_host_key
  save_artifacts
  print_instructions
}

main "$@"
