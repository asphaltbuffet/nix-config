# nixos/common/container-baseline.nix
#
# Container baseline (ADR-0020): the extraOptions every oci-containers service
# starts from. Each container adds only the capabilities it proves it needs,
# plus its own --user, --read-only, tmpfs and resource limits.
# Not a module: consume with `import ./container-baseline.nix`.
[
  "--cap-drop=ALL"
  "--security-opt=no-new-privileges"
]
