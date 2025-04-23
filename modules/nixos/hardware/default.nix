{
  config,
  lib,
  ...
}:
let
  inherit (lib) mkIf optionals mkOption;
  cfg = config.hardware;

  testHas =
    manufacturer:
    if cfg.graphics.manufacturer == null then
      false
    else if builtins.isString cfg.graphics.manufacturer then
      cfg.graphics.manufacturer == manufacturer
    else if builtins.isList cfg.graphics.manufacturer then
      builtins.elem manufacturer cfg.graphics.manufacturer
    else
      false;

  hasNvidia = testHas "nvidia";
  hasAmd = testHas "amd";
in
{
  imports = [
    ./storage
    ./backlight.nix
    ./biometrics.nix
    ./bluetooth.nix
    ./cooling.nix
    ./display.nix
    ./openrgb.nix
  ];

  options.hardware = {
    graphics = {
      manufacturer = mkOption {
        type =
          with lib.types;
          listOf (enum [
            "amd"
            "nvidia"
          ]);
        default = [ ];
        description = "The manufacturer of your GPU(s)";
      };

      hasNvidia = mkOption {
        type = lib.types.bool;
        default = hasNvidia;
        readOnly = true;
        description = "Whether or not the system has an Nvidia GPU";
      };

      hasAmd = mkOption {
        type = lib.types.bool;
        default = hasAmd;
        readOnly = true;
        description = "Whether or not the system has an AMD GPU";
      };
    };
  };

  config = {
    services.xserver.videoDrivers =
      (lib.optionals hasNvidia [ "nvidia" ])
      ++ (lib.optionals hasAmd [ "amdgpu" ])
      ++ (lib.optionals ((builtins.length cfg.graphics.manufacturer) == 0)) [
        "modesetting"
        "fbdev"
      ];

    hardware = {
      graphics.enable = true;

      nvidia-container-toolkit.enable = hasNvidia;
      nvidia = mkIf hasNvidia {
        package = config.boot.kernelPackages.nvidiaPackages.beta;
        open = true;
        nvidiaSettings = true;
        nvidiaPersistenced = true;
        modesetting.enable = true;
        powerManagement = {
          enable = true;
        };
      };
    };

    boot.kernelParams = optionals hasNvidia [
      "nvidia.NVreg_EnableResizableBar=1"
    ];
  };
}
