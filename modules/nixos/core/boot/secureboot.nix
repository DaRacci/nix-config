{
  inputs,
  config,
  lib,
  importExternals ? true,
  ...
}:
let
  inherit (lib)
    mkIf
    mkForce
    mkMerge
    mkEnableOption
    optional
    ;
  cfg = config.boot.secure;
in
{
  imports = optional importExternals inputs.lanzaboote.nixosModules.lanzaboote;

  options.boot.secure = {
    enable = mkEnableOption "enable secureboot";
  };

  config = mkMerge (
    optional importExternals (
      mkIf cfg.enable {
        boot = {
          loader.systemd-boot.enable = mkForce false;

          lanzaboote = {
            enable = true;
            pkiBundle = "/var/lib/sbctl";
            autoGenerateKeys.enable = true;
          };
        };

        host.persistence.directories = [ "/var/lib/sbctl" ];
      }
    )
  );
}
