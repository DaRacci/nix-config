{
  imports = [
    ./rgb.nix
    ./vfio.nix
    ./virtual-machine.nix

    ../shared/features/display-manager.nix
    ../shared/features/remote.nix
  ];
}
