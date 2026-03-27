# home/modules/pop/default.nix
{pkgs, ...}: {
  # pop: send emails from the terminal via SMTP.
  # SMTP credentials are injected from 1Password via home/modules/zsh/secrets.env.
  # Usage: pop --from you@proton.me --to recipient@example.com --subject "hi" --body "hello"
  home.packages = [pkgs.pop];
}
