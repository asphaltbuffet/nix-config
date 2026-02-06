# https://just.systems

# hostname := env('HOST', 'no_host')
hostname := `hostname`

[private]
default: help

# update flake
update:
    nix flake update

# build new config
build host=hostname:
    nh os build -H {{ host }} .

# build/activate new config + make boot default
switch host=hostname:
    nh os switch -H {{ host }} .

# update, rebuild and switch
update-switch host=hostname:
    nh os switch -uH {{ host }} .

# build/activate
test host=hostname:
    nh os test -H {{ host }} .

# remove old build artifacts
clean generations="3" since="5d":
    nh clean all --keep {{ generations }} -K {{ since }} -a

# show available commands
help:
    just --list
