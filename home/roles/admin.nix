{pkgs, ...}: {
  home.packages = with pkgs; [
    doggo
    fping
    ipcalc
    iperf
    lnav
    moreutils
    ncdu
    nmap
    trippy
    viddy
  ];
}
