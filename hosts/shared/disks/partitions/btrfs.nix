{
  config,
  lib,

  withSwap ? false,
  swapSize ? 0,

  withImpermanence ?
    config.environment.persistence ? "/persist" && config.environment.persistence."/persist".enable,

  ...
}:
{
  type = "btrfs";
  extraArgs = [ "-f" ]; # force overwrite
  subvolumes =
    {
      "@root" = lib.mkIf (!withImpermanence) {
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

      "@swap" = lib.mkIf withSwap {
        mountpoint = "/.swapvol";
        swap.swapfile.size = swapSize;
      };
    }
    // (lib.optionalAttrs withImpermanence {
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
