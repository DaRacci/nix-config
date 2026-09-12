{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:
let
  inherit (lib)
    escapeShellArg
    getExe'
    mkBefore
    mkEnableOption
    mkIf
    mkMerge
    mkOption
    types
    ;
  inherit (types)
    int
    str
    listOf
    addCheck
    ;
  inherit (builtins) listToAttrs foldl' toJSON;

  cfg = config.core.virtualisation;

  crtified = import "${inputs.crtified-nur}/default.nix" {
    inherit pkgs;
  };

in
{
  imports = [
    crtified.modules.virtualisation.nix
    ../desktop/vfio.nix
  ];

  options.core.virtualisation = {
    enable = mkEnableOption "virtualisation support";

    vmUsers = mkOption {
      type = listOf str;
      default = [ ];
      description = "Users that should receive `kvm` and `libvirtd` group membership for VM management.";
    };

    isolatedGuests = mkOption {
      type = listOf str;
      default = [
        "win11"
        "win11-gaming"
      ];
      description = "List of guests to apply isolation helpers to.";
    };

    bridgeInterface = mkOption {
      type = str;
      default = "br0";
      description = "Bridge interface used for libvirt networking.";
    };

    externalInterface = mkOption {
      type = str;
      default = "eth0";
      description = "Physical interface attached to bridge.";
    };

    cpuCores = mkOption {
      type = addCheck int (value: value >= 4);
      default = 24;
      description = "Total CPU core/thread count used for isolation helpers. Must be >= 4.";
    };

    gpu = {
      video = mkOption {
        type = str;
        default = "10de:1b06";
        description = "PCI address for passthrough GPU video device.";
      };

      audio = mkOption {
        type = str;
        default = "10de:1bef";
        description = "PCI address for passthrough GPU audio device.";
      };
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      assertions = [
        {
          assertion = cfg.cpuCores >= 4;
          message = "core.virtualisation.cpuCores must be >= 4 so AllowedCPUs isolation ranges stay valid.";
        }
      ];

      users.users = listToAttrs (
        map (user: {
          name = user;
          value.extraGroups = [
            "kvm"
            "libvirtd"
          ];
        }) cfg.vmUsers
      );

      boot = {

        extraModulePackages = mkBefore [ config.boot.kernelPackages.kvmfr ];

        extraModprobeConfig = ''
          options kvmfr static_size_mb=128
        '';
      };

      services.spice-autorandr.enable = true;

      virtualisation = {
        spiceUSBRedirection.enable = true;

        vfio = {
          enable = true;
          disableEFIfb = true;
          IOMMUType = "amd";
          devices = [
            cfg.gpu.video
            cfg.gpu.audio
          ];
        };

        sharedMemoryFiles = {
          looking-glass = {
            user = "racci";
            group = "qemu-libvirtd";
            mode = "660";
          };

        };

        libvirtd = {
          enable = true;
          onBoot = "ignore";
          onShutdown = "shutdown";

          allowedBridges = [ cfg.bridgeInterface ];

          qemu = {
            runAsRoot = false;
            swtpm.enable = true;

            verbatimConfig = ''
              cgroup_device_acl = [
                "/dev/null", "/dev/full", "/dev/zero",
                "/dev/random", "/dev/urandom",
                "/dev/ptmx", "/dev/kvm", "/dev/kqemu",
                "/dev/rtc", "/dev/hpet", "/dev/vfio/vfio",
                "/dev/kvmfr0",
              ]

            '';
          };
        };
      };

      networking = {
        interfaces."${cfg.bridgeInterface}".useDHCP = true;
        bridges."${cfg.bridgeInterface}".interfaces = [ cfg.externalInterface ];
      };

      systemd = {
        services = {
          "libvirt-nosleep@" = {
            description = ''Preventing sleep while libvirt domain "%i" is running'';
            serviceConfig = {
              Type = "simple";
              ExecStart = ''${pkgs.systemd}/bin/systemd-inhibit --what=sleep --why="Libvirt domain "%i" is running" --who=%U --mode=block sleep infinity'';
            };
          };

          libvirtd-config.script =
            let
              ovmfPackage =
                (pkgs.OVMFFull.override {
                  secureBoot = true;
                  tpmSupport = true;
                  msVarsTemplate = true;
                }).fd;
            in
            config.systemd.services.libvirtd.script
            + ''
              ln -s --force ${ovmfPackage}/FV/AAVMF_CODE{,.ms}.fd /run/libvirt/nix-ovmf/
              ln -s --force ${ovmfPackage}/FV/OVMF_CODE{,.ms}.fd /run/libvirt/nix-ovmf/
              ln -s --force ${ovmfPackage}/FV/AAVMF_VARS{,.ms}.fd /run/libvirt/nix-ovmf/
              ln -s --force ${ovmfPackage}/FV/OVMF_VARS{,.ms}.fd /run/libvirt/nix-ovmf/
            '';
        };

        tmpfiles.rules =
          let
            cpuIsolationRange = "${toString (cfg.cpuCores / 4)}-${toString ((cfg.cpuCores / 2) - 1)},${
              toString (cfg.cpuCores - (cfg.cpuCores / 4))
            }-${toString (cfg.cpuCores - 1)}";
            fullCpuRange = "0-${toString (cfg.cpuCores - 1)}";

            perMachine = getExe' pkgs.virtualisation-tools "per-machine";
            detachGpu = getExe' pkgs.virtualisation-tools "detach-gpu";
            attachGpu = getExe' pkgs.virtualisation-tools "attach-gpu";

            winIsolationStart = pkgs.writeShellScript "windows-isolation-start-wrapper" ''
              exec ${getExe' pkgs.virtualisation-tools "windows-isolation-start"} ${escapeShellArg cpuIsolationRange}
            '';

            winIsolationRelease = pkgs.writeShellScript "windows-isolation-release-wrapper" ''
              exec ${getExe' pkgs.virtualisation-tools "windows-isolation-release"} ${escapeShellArg fullCpuRange}
            '';

            machines =
              let
                prefix = "L+ /var/lib/libvirt/hooks/guests/";
              in
              foldl' (existing: new: existing ++ new) [ ] (
                map (guest: [
                  "${prefix}${guest}/prepare/begin/core-isolation - - - - ${winIsolationStart}"
                  "${prefix}${guest}/release/end/core-isolation - - - - ${winIsolationRelease}"

                  "${prefix}${guest}-single/prepare/begin/core-isolation - - - - ${winIsolationStart}"
                  "${prefix}${guest}-single/release/end/core-isolation - - - - ${winIsolationRelease}"
                  "${prefix}${guest}-single/prepare/begin/detach-gpu - - - - ${detachGpu}"
                  "${prefix}${guest}-single/release/end/attach-gpu - - - - ${attachGpu}"
                ]) cfg.isolatedGuests
              );

            qemuFirmware =
              let
                mkFirmwareJson =
                  {
                    name,
                    filenameExt ? "",
                    featuresExt ? [ ],
                    descriptionExt ? "",
                  }:
                  let
                    json = {
                      description = "OVMF with SB+SMM, SB enabled${descriptionExt}";
                      interface-types = [ "uefi" ];
                      mapping = {
                        device = "flash";
                        mode = "split";
                        executable = {
                          filename = "/run/libvirt/nix-ovmf/OVMF_CODE${filenameExt}.fd";
                          format = "raw";
                        };
                        nvram-template = {
                          filename = "/run/libvirt/nix-ovmf/OVMF_VARS${filenameExt}.fd";
                          format = "raw";
                        };
                      };
                      targets = [
                        {
                          architecture = "x86_64";
                          machines = [ "pc-q35-*" ];
                        }
                      ];
                      features = [
                        "acpi-s3"
                        "secure-boot"
                        "requires-smm"
                        "verbose-dynamic"
                      ]
                      ++ featuresExt;
                      tags = [ ];
                    };
                  in
                  pkgs.writeTextDir "share/firmware/${name}" (toJSON json);

                enrolledJson = mkFirmwareJson {
                  name = "30-edk2-ovmf-x64-sb-enrolled.json";
                  filenameExt = ".ms";
                  featuresExt = [ "enrolled-keys" ];
                  descriptionExt = ", MS certs enrolled";
                };

                sbJson = mkFirmwareJson {
                  name = "40-edk2-ovmf-x64-sb.json";
                };
              in
              pkgs.symlinkJoin {
                name = "qemu-firmware";
                paths = [
                  enrolledJson
                  sbJson
                ];
              };
          in
          mkBefore (
            [
              "L+ /var/lib/libvirt/hooks/qemu - - - - ${perMachine}"
              "L+ /var/lib/qemu/firmware - - - - ${qemuFirmware}/share/firmware"
            ]
            ++ machines
          );
      };

      services.udev.extraRules = mkBefore ''
        SUBSYSTEM=="kvmfr", OWNER="racci", GROUP="kvm", MODE="0660"
      '';

      environment = {
        sessionVariables.LIBVIRT_DEFAULT_URI = [ "qemu:///system" ];
        systemPackages = with pkgs; [
          virt-manager
          virtiofsd
          virtio-win
          win-spice
        ];
      };

      host.persistence.directories =
        let
          commonArgs = {
            user = "qemu-libvirtd";
            group = "qemu-libvirtd";
            mode = "u=rwx,g=rx,o=rx";
          };
        in
        [
          (commonArgs // { directory = "/var/lib/libvirt/qemu"; })
          (commonArgs // { directory = "/var/lib/libvirt/images"; })
          {
            directory = "/var/lib/libvirt/swtpm";
            mode = "u=rwx,g=rx,o=rx";
          }
          {
            directory = "/var/lib/libvirt/secrets";
            mode = "u=rw,g=x,o=x";
          }
          {
            directory = "/var/lib/swtpm-localca";
            mode = "u=rwx,g=rw,o=";
          }
        ];
    }
  ]);
}
