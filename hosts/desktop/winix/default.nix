{ flake, pkgs, ... }:
{

  imports = [
    flake.inputs.nixos-wsl.nixosModules.wsl

    ./hardware.nix

    "${flake}/hosts/shared/optional/wsl.nix"
    "${flake}/hosts/shared/optional/containers.nix"
  ];

  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  host = {
    drive = {
      format = "btrfs";
      name = "Nix";
    };

    device.isHeadless = true;
  };

  custom.remote = {
    enable = true;
    remoteDesktop.enable = true;
  };

  services = {
    dleyna-renderer.enable = false;
    dleyna-server.enable = false;
    power-profiles-daemon.enable = false;
    libinput.enable = false;

    gnome = {
      core-utilities.enable = false;
      gnome-browser-connector.enable = false;
      gnome-initial-setup.enable = false;
      gnome-user-share.enable = false;
      rygel.enable = false;
      gnome-online-accounts.enable = false;
      localsearch.enable = false;
      tinysparql.enable = false;
    };
  };

  networking.networkmanager.enable = false;

  documentation = {
    enable = false;
    man.enable = false;
  };

  environment = {
    sessionVariables = {
      # Don't want it using the 1080 ti or software rendering.
      MESA_VK_DEVICE_SELECT = "10de:2204";
      MESA_D3D12_DEFAULT_ADAPTER_NAME = "Nvidia GeForce RTX 3090";
      # LIBGL_KOPPER_DRI2 = "true"; # Fixes openGL in WSL, not really sure what is does.
    };

    gnome.excludePackages = with pkgs; [
      orca
      gnome-backgrounds
      gnome-bluetooth
      gnome-color-manager
      gnome-control-center
      gnome-shell-extensions
      gnome-tour
      gnome-user-docs
      glib
      gnome-menus
      gtk3.out
      xdg-user-dirs
      xdg-user-dirs-gtk
    ];
  };

  hardware.bluetooth.enable = false;

  boot = {
    systemd.enable = true;
    loader.systemd-boot.enable = false;
  };
}
