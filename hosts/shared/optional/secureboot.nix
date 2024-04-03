{ flake, lib, ... }: {
  imports = [ flake.inputs.lanzaboote.nixosModules.lanzaboote ];

  boot = {
    bootspec.enable = lib.mkForce true;
    loader.systemd-boot.enable = lib.mkForce false;

    lanzaboote = {
      enable = true;
      pkiBundle = "/etc/secureboot";
    };
  };

  host.persistence.directories = [
    "/etc/secureboot"
  ];
}
