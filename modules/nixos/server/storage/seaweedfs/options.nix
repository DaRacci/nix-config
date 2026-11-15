{
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    literalExpression
    mkEnableOption
    mkOption
    ;

  inherit (lib.types)
    bool
    package
    ;
in
{
  options.services.seaweedfs = {
    enable = mkEnableOption "SeaweedFS";

    openFirewall = mkOption {
      type = bool;
      default = false;
      description = "Whether to open ports in firewall for SeaweedFS services.";
    };

    package = mkOption {
      type = package;
      default = pkgs.seaweedfs;
      defaultText = literalExpression "pkgs.seaweedfs";
      description = "SeaweedFS package to use.";
    };
  };
}
