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
    image = inputs.stylix-wallpaper;
  };
}
