let
  grue = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBCNN0FY6PqVhfejv10JDfq56G1DTR4RWNjPpt/LSNRN" # wendigo
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEzLYqZEgfo5DqhCtJMN3sDvS5DO9Vxa6rvkQh7T1ZZv" # kushtaka
  ];
  users = grue;

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
