{ lib, config, modulesPath, ... }:
let
  cfg = config.abstractHome;
in
{
  options.abstractHome = {
    username = lib.mkOption {
      type = lib.types.str;
      default = builtins.throw "A username is required";
      description = "The username for the user";
      example = "racci";
    };

    empheral = {
      enable = lib.mkEnableOption "Empheral home";

      directories = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          "Documents"
          "Downloads"
          "Pictures"
          "Videos"
          "Music"
          "Templates"
          ".local/share/keyrings"
        ];
        description = ''
          The directories to create in the empheral home.
        '';
      };
    };
  };

  config =
    let
      persistencePath = "/persist/home/${cfg.username}";
      hostName = config.networking.hostName ? builtins.throw "A hostname is required";
    in
    {
      imports = [
        (modulesPath + "/home/common/global")
        (modulesPath + "/home/${cfg.username}/${hostName}.nix")
      ];

      home = {
        username = cfg.username;
        homeDirectory = "/home/${cfg.username}";
        stateVersion = "23.05";
        sessionPath = [ "$HOME/.local/bin" ];
      };
    } // lib.mkIf cfg.empheral.enable {
      home.persistence."${persistencePath}" = {
        allowOther = true;
        directories = cfg.empheral.directories;
      };
    };
}
