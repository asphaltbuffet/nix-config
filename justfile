# https://just.systems

[private]
default: help

update:
    nix flake update

build host:
    sudo nixos-rebuild build --flake .#{{ host }}

# rebuild and switch
switch host:
    sudo nixos-rebuild switch --flake .#{{host}}

help:
    just --list
