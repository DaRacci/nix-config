{ flake, pkgs, ... }: {

  imports = [
    flake.inputs.nixos-wsl.nixosModules.wsl

    ./hardware.nix

    "${flake}/hosts/shared/optional/wsl.nix"
    "${flake}/hosts/shared/optional/containers.nix"
  ];

  environment.systemPackages = with pkgs; [ wget ];

  host = {
    drive = {
      format = "btrfs";
      name = "Nix";
    };

    device.isHeadless = true;
  };

  boot = {
    systemd.enable = true;
    loader.systemd-boot.enable = false;
  };
}
