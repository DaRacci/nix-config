{ flake, pkgs, ... }: {

  imports = [
    flake.inputs.nixos-wsl.nixosModules.wsl
    ./hardware.nix
    "${flake}/hosts/shared/optional/wsl.nix"
    "${flake}/hosts/shared/optional/containers.nix"
  ];

  host = {
    drive = {
      format = "btrfs";
      name = "Nix";
    };
  };

  environment.systemPackages = with pkgs; [ wget ];
}
