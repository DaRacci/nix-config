{ flake, ... }: {

  imports = [
    flake.inputs.nixos-wsl.nixosModules.wsl
    ./hardware.nix
    ../common/optional/wsl.nix
  ];

  host = {
    drive = {
      format = "btrfs";
      name = "Nix";
    };
  };

  services.tailscale = {
    enable = true;
    useRoutingFeatures = "client";
  };
}
