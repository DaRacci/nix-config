{ config, lib, ... }: with lib; let
  cfg = config.host.device;
in
{
  options.host.device = rec {
    enable = mkEnableOption "device specification";

    role = mkOption {
      type = types.enum [ "desktop" "laptop" "server" ];
      default = throw "A role must be specified";
      description = "The role of the device";
    };

    purpose = mkOption {
      type = with types; listOf (enum [ "development" "gaming" "media" "office" "server" "virtualization" ]);
      default = [ ];
      description = "The purpose(s) of the device.";
    };

    isVirtual = mkOption {
      type = types.bool;
      default = builtins.hasAttr "wsl" config || builtins.hasAttr "proxmoxLXC" config;
      description = ''
        Whether the device is a virtual machine, container, or other virtualized environment.

        This is automatically set to true if the host is running in WSL or Proxmox LXC.
      '';
    };

    isHeadless = mkOption {
      type = types.bool;
      default = role == "server";
      description = ''
        Whether the device is headless, i.e. does not have a display is only accessible via SSH.

        This is automatically set to true if the device is a server.
      '';
    };
  };

  config = mkIf cfg.enable { };
}
