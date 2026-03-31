[
  # jj read-only subcommands
  "Bash(jj status*)"
  "Bash(jj log*)"
  "Bash(jj diff*)"
  "Bash(jj show*)"
  "Bash(jj describe --no-edit*)"
  # file search / content search
  "Bash(fd *)"
  "Bash(rg *)"
  # nix inspection (no building or switching)
  "Bash(nix flake show*)"
  "Bash(nix flake check*)"
  "Bash(nix eval *)"
  # just recipes (build/fmt mutate state but are low-risk and commonly needed)
  "Bash(just build*)"
  "Bash(just check*)"
  "Bash(just fmt*)"
  "Bash(just diff*)"
  "Bash(just hosts*)"
  "Bash(just lint*)"
]
