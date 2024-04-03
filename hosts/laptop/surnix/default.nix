{ self, ... }: {
  imports = [
    ./hardware.nix

    "${self}/hosts/shared/optional/pipewire.nix"
    "${self}/hosts/shared/optional/quietboot.nix"
    "${self}/hosts/shared/optional/gnome.nix"
    "${self}/hosts/shared/optional/gaming.nix"
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
