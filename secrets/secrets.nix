let
  grue = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOeLAZg365wMtiUxEAXWscq4jSRhXeHH8X3NNcTT0DoP";
  jsquats = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKU1/mEr6jtUNs5hESGvpCxz7g+xCsgHD5Hs4GRvL9Pr jsquats";
  sukey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJi8Ll+z8bwwbJdVTegv6ix4UetuduaThuPW9TYd7iMK sukey";

  users = [
    grue
    jsquats
    sukey
  ];

  wendigo = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDyrkGOX0lDcdIO5ehmjTzRhW9UEJwXRnFYAYbsFHz76 root@wendigo";
  kushtaka = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKfVXEd5gyLbgYnmmi9yrGL8zQcU2v8iXioIlSsCzZ57";
  snallygaster = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFe7wihS5yWkQCZhkJI2YNFj+p6M1wLos+s+GBaCNTJG root@snallygaster";

  systems = [
    wendigo
    kushtaka
    snallygaster
  ];
in {
  "tailscale.age" = {
    publicKeys = users ++ systems;
    armor = true;
  };
  "goreleaser.age" = {
    publicKeys = users ++ systems;
    armor = true;
  };
  "anthropic.age" = {
    publicKeys = users ++ systems;
    armor = true;
  };
}
