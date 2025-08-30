{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib) mkOption optionals mkIf;
  cfg = config.hardware.graphics;

  mkMesa =
    pkg:
    (pkg.override {
      galliumDrivers = [
        "llvmpipe"
      ]
      ++ (lib.optionals hasAmd [
        "radeonsi"
      ])
      ++ (lib.optionals hasNvidia [
        "zink"
      ])
      ++ (lib.optionals (config ? wsl) [
        "d3d12"
      ]);

      vulkanDrivers = [
        "swrast"
      ]
      ++ (lib.optionals hasAmd [
        "amd"
      ])
      ++ (lib.optionals (config ? wsl) [
        "microsoft-experimental"
      ]);

      eglPlatforms = lib.optionals (!config.host.device.isHeadless) [
        "x11"
        "wayland"
      ];
    }).overrideAttrs
      (old: {
        inherit ((pkgs.mesa-radeonsi-jupiter or old)) patches;

        mesonFlags = old.mesonFlags ++ [
          # Not compiling nouveau so disable it.
          (lib.mesonEnable "gallium-xa" false)
        ];

        outputs =
          let
            removals = lib.optionals (!config.host.device.isHeadless) [
              "spirv2dxil"
            ];
          in
          builtins.filter (out: !(builtins.elem out removals)) old.outputs;
      });

  testHas =
    manufacturer:
    if cfg.manufacturer == null then
      false
    else if builtins.isString cfg.manufacturer then
      cfg.manufacturer == manufacturer
    else if builtins.isList cfg.manufacturer then
      builtins.elem manufacturer cfg.manufacturer
    else
      false;

  hasNvidia = testHas "nvidia";
  hasAmd = testHas "amd";
in
{
  options.hardware.graphics = {
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

    reduceMesa = mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Whether or not to reduce the Mesa drivers to only the ones that are required for the system.

        WARNING: This can leave you without a working graphics driver if you have a GPU that is not supported by the drivers included in the list.
      '';
    };

    hasAcceleration = mkOption {
      type = lib.types.bool;
      default = hasNvidia || hasAmd;
      readOnly = true;
      description = "Whether or not the system has GPU acceleration";
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

  config = mkIf (cfg.manufacturer != [ ]) {
    services.xserver.videoDrivers =
      (lib.optionals hasNvidia [ "nvidia" ])
      ++ (lib.optionals hasAmd [ "amdgpu" ])
      ++ (lib.optionals ((builtins.length cfg.manufacturer) == 0)) [
        "modesetting"
        "fbdev"
      ];

    hardware = {
      graphics = {
        enable = true;
        package = mkIf cfg.reduceMesa (lib.mkForce (mkMesa pkgs.mesa));
        package32 = mkIf cfg.reduceMesa (lib.mkForce (mkMesa pkgs.pkgsi686Linux.mesa));
      };

      nvidia-container-toolkit.enable = hasNvidia;
      nvidia = mkIf hasNvidia {
        package = config.boot.kernelPackages.nvidiaPackages.latest;
        open = true;
        nvidiaSettings = true;
        nvidiaPersistenced = false;
        modesetting.enable = true;
        powerManagement = {
          enable = true;
        };
      };
    };

    boot.kernelParams =
      optionals hasNvidia [
        "nvidia.NVreg_EnableResizableBar=1"
      ]
      ++ optionals hasAmd [
        "amdgpu.dcdebugmask=0x400" # Fix stuttering under wayland on Kernel 6.11+
        "amdgpu.dc=1" # Use modern DC Engine
      ];

    # https://wiki.nixos.org/wiki/AMD_GPU#HIP
    systemd.tmpfiles.rules = mkIf hasAmd (
      let
        rocmEnv = pkgs.symlinkJoin {
          name = "rocm-combined";
          paths = with pkgs.rocmPackages; [
            rocblas
            hipblas
            clr
          ];
        };
      in
      [
        "L+    /opt/rocm   -    -    -     -    ${rocmEnv}"
      ]
    );
  };
}
