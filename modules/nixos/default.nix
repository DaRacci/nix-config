{
  vfio = import ./vfio.nix;
  host = import ./host;
  tailscale = import ./tailscale.nix;
  shared = import ./shared;
  virtual-machine = import ./virtual-machine.nix;
}
