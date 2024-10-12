{ config, pkgs, lib, ... }:
let
  inherit (lib) mkIf optionals mkOption;
  cfg = config.hardware;
in
{
  imports = [
    ./backlight.nix
    ./biometrics.nix
    ./bluetooth.nix
    ./cooling.nix
    ./openrgb.nix
  ];

  options.hardware = {
    graphics = {
      manufacturer = mkOption {
        type = lib.types.enum [ "unknown" "amd" "intel" "nvidia" ];
        default = "unknown";
        description = "The manufacturer of your GPU";
      };
    };
  };

  config = {
    environment.systemPackages = with pkgs; [
      nvtopPackages.full
    ];

    services.xserver.videoDrivers =
      if (cfg.graphics.manufacturer == "nvidia") then [ "nvidia" ]
      else if (cfg.graphics.manufacturer == "amd") then [ "amdgpu" ]
      else [ "modesetting" "fbdev" ];

    hardware = {
      graphics.enable = true;

      nvidia-container-toolkit.enable = true;
      nvidia = mkIf (cfg.graphics.manufacturer == "nvidia") {
        package = config.boot.kernelPackages.nvidiaPackages.beta;
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

    boot.kernelParams = optionals (cfg.graphics.manufacturer == "nvidia") [
      "nvidia.NVreg_EnableResizableBar=1"
      "nvidia.NVreg_PreserveVideoMemoryAllocations=1"
    ];
  };
}
