{ flake, ... }: {
  imports = [
    ./hardware.nix

    "${flake}/hosts/shared/optional/pipewire.nix"
    "${flake}/hosts/shared/optional/gnome.nix"
    "${flake}/hosts/shared/optional/gaming.nix"
  ];

  boot = {
    quiet.enable = true;
    secure.enable = true;
    systemd.enable = true;
  };

  host.persistence = {
    type = "snapshot";
  };

  microsoft-surface.kernelVersion = "6.5.5";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  nix = {
    distributedBuilds = true;
    extraOptions = ''builders-use-substitutes = true'';
    buildMachines = [{
      hostName = "nixe";
      system = "x86_64-linux";
      protocol = "ssh-ng";
      systems = [ "x86_64-linux" ];
      maxJobs = 1;
      speedFactor = 2;
      supportedFeatures = [ "nixos-test" "benchmark" "big-parallel" "kvm" ];
      mandatoryFeatures = [ ];
    }];
  };
}
