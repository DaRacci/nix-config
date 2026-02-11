{
  config,
  lib,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkDefault
    mkOption
    mkMerge
    mkIf
    ;
  inherit (lib.types)
    listOf
    nullOr
    bool
    enum
    ;
  cfg = config.host.device;
in
{
  options.host.device = {
    enable = mkEnableOption "device specification";

    role = mkOption {
      type = nullOr (enum [
        "desktop"
        "laptop"
        "server"
      ]);
      description = "The role of the device";
    };

    purpose = mkOption {
      type = listOf (enum [
        "development"
        "gaming"
        "media"
        "office"
        "server"
        "virtualization"
      ]);
      default = [ ];
      description = "The purpose(s) of the device.";
    };

    isVirtual = mkOption {
      type = bool;
      default = builtins.hasAttr "wsl" config || builtins.hasAttr "proxmoxLXC" config;
      description = ''
        Whether the device is a virtual machine, container, or other virtualized environment.

        This is automatically set to true if the host is running in WSL or Proxmox LXC.
      '';
    };

    isHeadless = mkOption {
      type = bool;
      default = false;
      description = ''
        Whether the device is headless, i.e. does not have a display is only accessible via SSH.

        This is automatically set to true if the device is a server.
      '';
    };
  };

  config = mkMerge [
    {
      assertions = [
        {
          assertion = cfg.role != null;
          message = "host.device.role is required to be set.";
        }
      ];
    }

    (mkIf cfg.enable {
      host.device.isHeadless = mkDefault (cfg.role == "server");
    })
  ];
}
