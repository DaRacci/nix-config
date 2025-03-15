{
  config,
  lib,

  withRoot ? false,
  withSwap ? false,
  swapSize ? 0,
  withImpermanence ?
    config.environment.persistence ? "/persist" && config.environment.persistence."/persist".enable,

  ...
}:
{
  type = "btrfs";
  extraArgs = [ "-f" ]; # force overwrite
  subvolumes = {
    "@root" = lib.mkIf withRoot {
      mountpoint = "/";
      mountOptions = [
        "compress=zstd"
        "noatime"
      ];
    };

    "@persist" = lib.mkIf withImpermanence {
      mountpoint = "/persist";
      mountOptions = [
        "compress=zstd"
        "noatime"
      ];
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
  };
}
