{ ... }: {
  imports = [
    ./auto-upgrade.nix
    ./display-manager.nix
  ];

  options.custom = { };
  config = { };
}