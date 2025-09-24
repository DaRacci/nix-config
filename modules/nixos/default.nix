{
  boot = import ./boot;
  hardware = import ./hardware;
  vfio = import ./vfio.nix;
  host = import ./host;
  services = import ./services;
  shared = import ./shared;
  virtual-machine = import ./virtual-machine.nix;
}
