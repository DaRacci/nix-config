{ flake, pkgs, ... }: {

  imports = [
    flake.inputs.nixos-wsl.nixosModules.wsl

    ./hardware.nix

    "${flake}/hosts/shared/optional/wsl.nix"
    "${flake}/hosts/shared/optional/containers.nix"
  ];

  boot.systemd.enable = true;

  host = {
    drive = {
      format = "btrfs";
      name = "Nix";
    };
  };

  boot.loader.systemd-boot.enable = false;
  environment.systemPackages = with pkgs; [ wget ];
}
