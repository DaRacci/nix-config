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

  config = mkIf cfg.enable {
    boot = {
      bootspec.enable = mkForce true;
      loader.systemd-boot.enable = mkForce false;

      lanzaboote = {
        enable = true;
        pkiBundle = "/var/lib/sbctl";
      };
    };

    host.persistence.directories = [ "/var/lib/sbctl" ];
  };
}
