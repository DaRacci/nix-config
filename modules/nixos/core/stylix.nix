{
  inputs,
  config,
  lib,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    literalExpression
    ;
  cfg = config.core.stylix;
in
{
  imports = [ inputs.stylix.nixosModules.stylix ];

  options.core.stylix = {
    enable = mkEnableOption "Stylix configuration" // {
      default = !config.host.device.isHeadless;
      defaultText = literalExpression "!config.host.device.isHeadless";
    };
  };

  config = {
    stylix = {
      enable = cfg.enable;
      polarity = "dark";
      base16Scheme = "${inputs.stylix.inputs.tinted-schemes}/base16/tokyo-night-dark.yaml";
    };
  };
}
