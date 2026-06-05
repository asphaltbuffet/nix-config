# Pull-based auto-deploy via GitHub Pages store-path URLs

Opted-in hosts receive automatic updates by polling a URL rather than being pushed to. CI builds each host's closure, pushes it to the Cachix binary cache, and publishes the resulting store path to GitHub Pages at `https://asphaltbuffet.github.io/nix-config/hosts/<hostname>/store-path`. A systemd timer on each opted-in host fetches its URL and applies the config.

Push-based tools (`deploy-rs`, `colmena`) require an operator machine to be online and authenticated at deploy time — unsuitable for unattended family laptops that may be offline or behind NAT. The GitHub Pages URL acts as a stable, authenticated, zero-infrastructure coordination point: the host only needs outbound HTTPS, no SSH exposure or VPN required. The trade-off is eventual consistency — a host applies the update when its timer fires, not the moment CI completes.
