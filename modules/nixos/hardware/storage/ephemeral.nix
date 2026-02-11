{ config, lib, ... }:
let
  inherit (lib)
    mkIf
    mkMerge
    mkOption
    mkEnableOption
    ;
  inherit (lib.types) enum int str;

  cfg = config.hardware.storage.root;
in
{
  options.hardware.storage.root.ephemeral = {
    enable = mkEnableOption "usage of an ephemeral root that is reset on boot";

    type = mkOption {
      type = enum [
        "btrfs"
        "tmpfs"
      ];
      description = ''
        The type of ephemeral root to use.
      '';
    };

    tmpfsSize = mkOption {
      type = int;
      default = 4;
      description = ''
        The size of the tmpfs root in GiB.
      '';
    };

    paritionLabel = mkOption {
      type = str;
    };
  };

  config = mkMerge [
    {
      hardware.storage.root.ephemeral =
        let
          inherit (config.disko.devices.disk."${config.hardware.storage.root.name}".content) partitions;
          partition = if cfg.enableLuks then partitions.luks else partitions.root;
        in
        lib.stringAfter "/dev/disk/by-partlabel/" partition.label;
    }

    (mkIf cfg.ephemeral.enable {
      disko.devices = {
        nodev."/" = lib.mkIf (cfg.ephemeral.type == "tmpfs") (
          import ./partitions/tmpfs.nix { size = cfg.ephemeral.tmpfsSize; }
        );
      };

      boot.initrd =
        let
          phase1Systemd = config.boot.initrd.systemd.enable;
          wipeScript = ''
            mkdir /tmp -p
            MNTPOINT=$(mktemp -d)
            (
              mount -t btrfs -o subvol=/ /dev/disk/by-partlabel/${cfg.ephemeral.paritionLabel} "$MNTPOINT"
              trap 'umount "$MNTPOINT"' EXIT

              echo "Creating needed directories"
              mkdir -p "$MNTPOINT"/@persist/var/{log,lib/{nixos,systemd}}

              echo "Cleaning root subvolume"
              btrfs subvolume list -o "$MNTPOINT/@root" | cut -f9 -d ' ' |
              while read -r subvolume; do
                btrfs subvolume delete "$MNTPOINT/$subvolume"
              done && btrfs subvolume delete "$MNTPOINT/@root"

              echo "Restoring blank subvolume"
              btrfs subvolume snapshot "$MNTPOINT/@root-blank" "$MNTPOINT/@root"
            )
          '';
        in
        lib.mkIf (cfg.ephemeral.type == "btrfs") {
          supportedFilesystems = [ "btrfs" ];
          postDeviceCommands = lib.mkIf (!phase1Systemd) (lib.mkBefore wipeScript);
          systemd.services.restore-root = lib.mkIf phase1Systemd {
            description = "Rollback btrfs rootfs";
            wantedBy = [ "initrd.target" ];
            requires = [ "dev-disk-by\\x2dpartlabel-${cfg.ephemeral.paritionLabel}.device" ];
            after = [
              "dev-disk-by\\x2dpartlabel-${cfg.ephemeral.paritionLabel}.device"
              "systemd-cryptsetup@${cfg.ephemeral.paritionLabel}.service"
            ];
            before = [ "sysroot.mount" ];
            unitConfig.DefaultDependencies = "no";
            serviceConfig.Type = "oneshot";
            script = wipeScript;
          };
        };
    })
  ];
}
