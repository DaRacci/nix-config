{ config, pkgs, lib, ... }: with lib; let cfg = config.purpose.gaming; in {
  imports = [
    ./modding.nix
    ./osu.nix
    ./roblox.nix
    ./steam.nix
    ./vr.nix
  ];

  options.purpose.gaming = {
    enable = mkEnableOption "Gaming support base.";

    controllerSupport = mkEnableOption "controller support";
  };

  config = mkIf cfg.enable {
    user.persistence.directories = [ "Games" ];

    home.packages = optionals cfg.controllerSupport (with pkgs.unstable; [ dualsensectl trigger-control ]);
  };
}
