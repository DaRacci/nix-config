{ flake, pkgs, ... }: {

  imports = [
    flake.inputs.nixos-wsl.nixosModules.wsl
    ./hardware.nix
    ../common/optional/wsl.nix
    ../common/optional/containers.nix
  ];

  host = {
    drive = {
      format = "btrfs";
      name = "Nix";
    };
  };

  environment.systemPackages = with pkgs; [ wget ];
}
