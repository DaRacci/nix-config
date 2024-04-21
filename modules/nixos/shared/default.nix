{ ... }: {
  imports = [
    ./auto-upgrade.nix
    ./core.nix
    ./display-manager.nix
  ];

  options.custom = { };
  config = { };
}
