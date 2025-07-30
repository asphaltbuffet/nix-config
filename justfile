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

clean generations="3" since="5d":
    nh clean all --keep {{ generations }} -K {{ since }} -a

help:
    just --list
