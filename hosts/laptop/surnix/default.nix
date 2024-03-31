{ ... }: {
  imports = [
    ./hardware.nix

    ../common/optional/pipewire.nix
    ../common/optional/quietboot.nix
    ../common/optional/gnome.nix
    ../common/optional/gaming.nix
  ];

  host.persistence = {
    type = "snapshot";
  };

  microsoft-surface.kernelVersion = "6.5.5";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  nix.distributedBuilds = true;
  nix.extraOptions = ''builders-use-substitutes = true'';
  nix.buildMachines = [{
    hostName = "nixe";
    system = "x86_64-linux";
    protocol = "ssh-ng";
    systems = [ "x86_64-linux" ];
    maxJobs = 1;
    speedFactor = 2;
    supportedFeatures = [ "nixos-test" "benchmark" "big-parallel" "kvm" ];
    mandatoryFeatures = [ ];
  }];
}
