{ flake, pkgs, ... }: {

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

  environment.systemPackages = with pkgs; [ wget ];

  services.tailscale = {
    enable = true;
    useRoutingFeatures = "client";
  };
}
