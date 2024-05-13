{
  vfio = import ./vfio.nix;
  host = import ./host;
  shared = import ./shared;
  virtual-machine = import ./virtual-machine.nix;
}
