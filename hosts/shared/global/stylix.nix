{
  pkgs,
  inputs,
  config,
  ...
}:
{
  imports = [ inputs.stylix.nixosModules.stylix ];

  stylix = {
    enable = !config.host.device.isHeadless;
    polarity = "dark";
    image = pkgs.fetchurl {
      url = "https://nextcloud.racci.dev/s/Hy8qkAWYwqSTjKp/download/17.jpeg";
      sha256 = "sha256-dYkMPG/kTs0zgwHDFGkzN4gwFqefDWfMC9RUSBVezXE=";
    };
  };
}
