{ flake, pkgs, ... }: {

  imports = [
    ./hardware.nix

    "${flake}/hosts/shared/optional/containers.nix"
    "${flake}/hosts/shared/optional/virtualisation.nix"

    "${flake}/hosts/shared/optional/gdm.nix"
    "${flake}/hosts/shared/optional/hyprland.nix"

    "${flake}/hosts/shared/optional/pipewire.nix"
    "${flake}/hosts/shared/optional/quietboot.nix"
    "${flake}/hosts/shared/optional/gaming.nix"
    "${flake}/hosts/shared/optional/tailscale.nix"
  ];

  programs.nix-ld.enable = true;

  host = {
    drive = {
      enable = true;

      format = "btrfs";
      name = "Nix";
    };

    persistence = {
      enable = true;
      type = "tmpfs";

      directories = [
        "/var/lib/private/ollama"
      ];
    };
  };

  networking = {
    firewall = {
      allowedUDPPorts = [ 9944 8082 9942 9943 7860 ];
      allowedTCPPorts = [ 9999 22 5990 9944 8082 9942 9943 8080 7860 ];
    };
  };

  services.netdata = {
    enable = true;
  };

  services.ollama = {
    enable = true;
    package = pkgs.unstable.ollama;
    acceleration = "cuda";
    environmentVariables = {
      OLLAMA_ORIGINS = "http://192.168.0.0:*,app://obsidian.md:*";
    };
  };
}
