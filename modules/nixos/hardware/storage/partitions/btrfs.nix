{
  config,
  lib,
}:
let
  cfg = config.hardware.storage;
in
{
  type = "btrfs";
  extraArgs = [ "-f" ]; # force overwrite
  subvolumes =
    {
      # Only enable if not using ephemeral root or if using snapshotted root
      "@root" = lib.mkIf (!cfg.root.ephemeral.enable || cfg.root.ephemeral.type == "btrfs") {
        mountpoint = "/";
        mountOptions = [ "compress=zstd" ];
      };

      "@nix" = {
        mountpoint = "/nix";
        mountOptions = [
          "compress=zstd"
          "noatime"
        ];
      };

      "@swap" = lib.mkIf cfg.root.physicalSwap.enable {
        mountpoint = "/.swapvol";
        swap.swapfile.size = "${cfg.root.physicalSwap.size}GiB";
      };
    }
    // (lib.optionalAttrs cfg.withImpermanence {
      "@persist" = {
        mountpoint = "/persist";
        mountOptions = [ "compress=zstd" ];
      };

      "@persist/home" = {
        mountpoint = "/persist/home";
        mountOptions = [ "compress=zstd" ];
      };

      "@persist/var/log" = {
        mountpoint = "/persist/var/log";
        mountOptions = [ "compress=zstd" ];
      };
    });
}
