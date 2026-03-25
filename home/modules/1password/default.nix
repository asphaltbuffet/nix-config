{pkgs, ...}: {
  systemd.user.services."1password" = {
    Unit = {
      Description = "1Password GUI";
      After = "graphical-session.target";
    };
    Service = {
      ExecStart = "${pkgs._1password-gui}/bin/1password --silent";
      Restart = "on-failure";
    };
    Install = {
      WantedBy = ["graphical-session.target"];
    };
  };
}
