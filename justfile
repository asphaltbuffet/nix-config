# https://just.systems

# hostname := env('HOST', 'no_host')
hostname := `hostname`

[private]
default: help

# update flake
update:
    nix flake update

# rebuild but do not make active
build host=hostname:
    nh os build -H {{ host }} .

# rebuild and switch
switch host=hostname:
    nh os switch -H {{ host }} .

# remove old build artifacts
clean generations="3" since="5d":
    nh clean all --keep {{ generations }} -K {{ since }} -a

# show available commands
help:
    just --list
