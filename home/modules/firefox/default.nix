{pkgs, ...}: {
  programs.firefox = {
    enable = true;
    profiles = {
      default = {
        id = 0;
        name = "default";
        settings = {
          # "browser.startup.homepage" = "https://duckduckgo.com";
          # "browser.search.defaultenginename" = "DuckDuckGo";
          # "browser.search.order.1" = "DuckDuckGo";

          # "signon.rememberSignons" = false;
          "widget.use-xdg-desktop-portal.file-picker" = 1;
          "browser.aboutConfig.showWarning" = false;
          "browser.compactmode.show" = true;
          "browser.cache.disk.enable" = false; # Be kind to hard drive

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
