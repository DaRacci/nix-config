{
  pkgs,
  lib,
  disk,

  withSwap ? false,
  swapSize,

  ...
}:
{
  disko.devices = {
    disk = {
      disk0 = {
        type = "disk";
        device = disk;
        content = {
          type = "gpt";
          partitions = {
            ESP = import ./partitions/esp.nix;
            luks = {
              size = "100%";
              content = {
                type = "luks";
                name = "encrypted-nixos";
                passwordFile = "/tmp/disko-password"; # this is populated by bootstrap-nixos.sh
                settings = {
                  allowDiscards = true;
                  # https://github.com/hmajid2301/dotfiles/blob/a0b511c79b11d9b4afe2a5e2b7eedb2af23e288f/systems/x86_64-linux/framework/disks.nix#L36
                  crypttabExtraOpts = [
                    "fido2-device=auto"
                    "token-timeout=10"
                  ];
                };

                content = import ./partitions/btrfs.nix {
                  inherit lib withSwap swapSize;
                };
              };
            };
          };
        };
      };
    };
  };

  environment.systemPackages = [
    pkgs.yubikey-manager # For luks fido2 enrollment before full install
  ];
}
