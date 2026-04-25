{
  imports = [
    ./rgb.nix
    ./vfio.nix
    ./virtual-machine.nix
  ];

  config = {
    core = {
      display-manager.enable = true;
      remote.enable = true;
    };
  };
}
