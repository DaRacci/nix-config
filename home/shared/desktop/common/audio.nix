{ config, pkgs, ... }:
{
  home.packages = [ config.services.easyeffects.package ];

  services.easyeffects = {
    enable = true;
    package = pkgs.easyeffects;
    preset = "male-voice-v2";
  };

  core.uwsm.sliceAllocation.app = [ "easyeffects" ];

  user.files.persistence.directories = [ ".config/easyeffects" ];
}
