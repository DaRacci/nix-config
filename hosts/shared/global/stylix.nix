{
  inputs,
  config,
  ...
}:
{
  imports = [ inputs.stylix.nixosModules.stylix ];

  stylix = {
    enable = !config.host.device.isHeadless;
    polarity = "dark";
    base16Scheme = "${inputs.stylix.inputs.tinted-schemes}/base16/tokyo-night-dark.yaml";
  };
}
