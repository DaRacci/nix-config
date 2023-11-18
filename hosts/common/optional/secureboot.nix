{ flake, lib, hasPersistence, ... }: builtins.foldl' lib.recursiveUpdate { } [
  {
    imports = [ flake.inputs.lanzaboote.nixosModules.lanzaboote ];

    boot = {
      bootspec.enable = lib.mkForce true;
      loader.systemd-boot.enable = lib.mkForce false;

      lanzaboote = {
        enable = true;
        pkiBundle = "/etc/secureboot";
      };
    };
  }
  (lib.optionalAttrs
    (hasPersistence)
    {
      environment.persistence."/persist".directories = [
        "/etc/secureboot"
      ];
    })
]
