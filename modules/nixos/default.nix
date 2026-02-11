{
  boot = import ./boot;
  hardware = import ./hardware;
  hm-helper = import ./hm-helper;
  vfio = import ./vfio.nix;
  host = import ./host;
  services = import ./services;
  shared = import ./shared;
  virtual-machine = import ./virtual-machine.nix;
}
