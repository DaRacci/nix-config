{
  # encrypted-root = import ./encrypted-root.nix;
  # rgb = import ./rgb.nix;
  # containers = import ../containers;
  vfio = import ./vfio.nix;
  host = import ./host;
  tailscale = import ./tailscale.nix;
  shared = import ./shared;
}