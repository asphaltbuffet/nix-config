{...}: {
  programs.firefox = {
    enable = true;
    profiles = {
      default = {
        id = 0;
        name = "default";
        settings = {
          "widget.use-xdg-desktop-portal.file-picker" = 1;
          "browser.aboutConfig.showWarning" = false;
          "browser.compactmode.show" = true;
          "browser.cache.disk.enable" = true;
          "browser.cache.disk.capacity" = 524288; # 512 MB in KB — fine for NVMe SSD

          # Firefox 75+ remembers the last workspace it was opened on as part of its session management.
          # This is annoying, because I can have a blank workspace, click Firefox from the launcher, and
          # then have Firefox open on some other workspace.
          "widget.disable-workspace-management" = true;
        };
        search = {
          force = true;
          default = "Kagi";

          engines = {
            "Kagi" = {
              urls = [
                {
                  template = "https://kagi.com/search?";
                  params = [
                    {
                      name = "q";
                      value = "{searchTerms}";
                    }
                  ];
                }
              ];
            };
          };
        };
      };
    };
  };
}
