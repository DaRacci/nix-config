{ flake, pkgs, ... }:
{

  imports = [
    flake.inputs.nixos-wsl.nixosModules.wsl

    ./hardware.nix

    "${flake}/hosts/shared/optional/wsl.nix"
    "${flake}/hosts/shared/optional/containers.nix"
  ];

  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  environment = {
    systemPackages = with pkgs; [ wget ];
    sessionVariables = {
      # Don't want it using the 1080 ti or software rendering.
      MESA_VK_DEVICE_SELECT = "10de:2204";
      MESA_D3D12_DEFAULT_ADAPTER_NAME = "Nvidia GeForce RTX 3090";
      LIBGL_KOPPER_DRI2 = "true"; # Fixes openGL in WSL, not really sure what is does.
    };
  };

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
