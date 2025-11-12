let
  grue = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBCNN0FY6PqVhfejv10JDfq56G1DTR4RWNjPpt/LSNRN";
  users = [grue];

  wendigo = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDyrkGOX0lDcdIO5ehmjTzRhW9UEJwXRnFYAYbsFHz76 root@wendigo";
  kushtaka = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKfVXEd5gyLbgYnmmi9yrGL8zQcU2v8iXioIlSsCzZ57";

  systems = [wendigo kushtaka];
in {
  "tailscale.age" = {
    publicKeys = users ++ systems;
    armor = true;
  };
}
