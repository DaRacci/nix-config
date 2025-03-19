{
  config,
  lib,
}:
{
  type = "luks";
  name = "encrypted-nixos";
  passwordFile = "/tmp/disko-password"; # this is populated by bootstrap-nixos.sh
  extraOpenArgs = [
    "--perf-no_read_workqueue"
    "--perf-no_write_workqueue"
  ];
  settings = {
    allowDiscards = true;
    # https://github.com/hmajid2301/dotfiles/blob/a0b511c79b11d9b4afe2a5e2b7eedb2af23e288f/systems/x86_64-linux/framework/disks.nix#L36
    crypttabExtraOpts = [
      "fido2-device=auto"
      "token-timeout=10"
    ];
  };

  content = import ./btrfs.nix { inherit config lib; };
}
