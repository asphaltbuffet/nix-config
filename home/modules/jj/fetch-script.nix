{pkgs}:
pkgs.writeShellApplication {
  name = "jj-git-fetch-all";
  runtimeInputs = with pkgs; [
    curl
    fd
    systemd
    jujutsu
  ];
  text = builtins.readFile ./jj-git-fetch.sh;
}
