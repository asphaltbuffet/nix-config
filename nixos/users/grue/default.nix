{ ... }: {
  isNormalUser = true;
  description = "grue";
  initialPassword = "nixos";
  extraGroups = [ "networkmanager" "wheel" ];
}
