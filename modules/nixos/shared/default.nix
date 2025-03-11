{ ... }:
{
  imports = [
    ./auto-upgrade.nix
    ./core.nix
    ./display-manager.nix
    ./remote.nix
  ];

  options.custom = { };
  config = { };
}
