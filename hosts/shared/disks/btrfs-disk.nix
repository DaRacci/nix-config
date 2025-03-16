{
  disk,
  withSwap ? false,
  swapSize ? 2,
}:
{
  config,
  lib,

  ...
}:
{
  imports = [
    ./neededForBoot.nix
  ];

  disko.devices = {
    disk = {
      disk0 = {
        type = "disk";
        device = disk;
        content = {
          type = "gpt";
          partitions = {
            ESP = import ./partitions/esp.nix;
            root = {
              size = "100%";
              content = import ./partitions/btrfs.nix {
                inherit
                  config
                  lib
                  withSwap
                  swapSize
                  ;
              };
            };
          };
        };
      };
    };
  };
}
