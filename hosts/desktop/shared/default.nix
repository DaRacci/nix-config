{
  inputs,
  pkgs,
  ...
}:
{
  imports = [
    ./appimage.nix
    ./power.nix
    ./scheduler.nix

    inputs.chaotic-nyx.nixosModules.default
  ];

  chaotic = {

  };

  services.gvfs.enable = true;

  services = {
    geoclue2 = {
      enable = true;
      enableWifi = true;
    };

    automatic-timezoned = {
      enable = false;
      package = pkgs.automatic-timezoned;
    };
  };

  location.provider = "geoclue2";
}
