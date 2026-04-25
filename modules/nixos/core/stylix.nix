{
  inputs,
  config,
  lib,
  importExternals ? true,
  ...
}:
let
  inherit (lib)
    literalExpression
    mkIf
    optional
    mkEnableOption
    ;
  cfg = config.core.stylix;
in
{
  options.core.stylix = {
    enable = mkEnableOption "Stylix configuration" // {
      default = !config.host.device.isHeadless;
      defaultText = literalExpression "!config.host.device.isHeadless";
    };
  };

  imports = optional importExternals inputs.stylix.nixosModules.stylix;

  config = mkIf cfg.enable {
    stylix = {
      enable = true;
      polarity = "dark";
      base16Scheme = "${inputs.stylix.inputs.tinted-schemes}/base16/tokyo-night-dark.yaml";
    };
  };
}
