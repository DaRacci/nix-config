{ flake, lib, hasPersistence, ... }:
let inherit (flake.inputs) lanzaboote; in {
  imports = [ lanzaboote.nixosModules.lanzaboote ];

  boot = {
    bootspec.enable = lib.mkForce true;
    loader.systemd-boot.enable = lib.mkForce false;

    lanzaboote = {
      enable = true;
      pkiBundle = "/etc/secureboot";
    };
  };
} // lib.optionalAttrs (hasPersistence) {
  environment.persistence."/persist".directories = [
    "/etc/secureboot"
  ];
}
