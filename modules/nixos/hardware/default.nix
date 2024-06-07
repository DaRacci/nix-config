{ config, pkgs, lib, ... }:
let
  inherit (lib) mkIf mkEnableOption;
  cfg = config.hardware;
in
{
  imports = [
    ./backlight.nix
    ./biometrics.nix
    ./cooling.nix
    ./openrgb.nix
  ];

  options.hardware = {
    graphics = {
      hasNvidia = mkEnableOption "Whether the device has an NVIDIA GPU";
    };
  };

  config = mkIf cfg.graphics.hasNvidia {
    environment.systemPackages = with pkgs; [ nvtop ];

    services.xserver.videoDrivers = [ "nvidia" ];

    hardware = {
      opengl.enable = true;

      nvidia = {
        # package = config.boot.kernelPackages.nvidiaPackages.stable;
        open = true;
        nvidiaSettings = true;
        nvidiaPersistenced = true;
        modesetting.enable = true;
        forceFullCompositionPipeline = true;
        powerManagement = {
          enable = true;
        };
      };
    };

    boot.kernelParams = [ "nvidia.NVreg_EnableResizableBar=1" "nvidia.NVreg_PreserveVideoMemoryAllocations=1" ];
  };
}
