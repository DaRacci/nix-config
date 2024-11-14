{ flake, inputs, pkgs, lib, config, ... }:
let
  caches = {
    cachenixosorg = {
      url = "https://cache.nixos.org";
      key = "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=";
    };

    nixcommunitycachixorg = {
      url = "https://nix-community.cachix.org";
      key = "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=";
    };

    cacheraccidev = {
      url = "https://cache.racci.dev/racci";
      key = "cache.racci.dev-1:/i2mJWsMm9rDxIPH3bqNXJXd/wPEDRsJFYiTKh8JPF0=";
    };
  };

  postBuildHook = pkgs.writeShellApplication {
    name = "post-build-hook";
    runtimeInputs = [ pkgs.attic-client ];
    text = ''
      JWT=$(cat ${config.sops.secrets.CACHE_PUSH_KEY.path})
      attic login build-auto-push ${caches.cacheraccidev.url} "$JWT" || exit 1
      attic push build-auto-push:racci "$OUT_PATHS" &
    '';
  };
in
{
  sops.secrets.CACHE_PUSH_KEY = {
    sopsFile = "${flake}/hosts/secrets.yaml";
  };

  nix = {
    settings = rec {
      trusted-users = [ "root" "@wheel" ];
      auto-optimise-store = lib.mkForce true;
      experimental-features = [ "nix-command" "flakes" ];

      substituters = map (sub: sub.url) (lib.attrValues caches);
      trusted-substituters = substituters;
      trusted-public-keys = map (sub: sub.key) (lib.attrValues caches);

      post-build-hook = lib.getExe postBuildHook;
    };

    gc = {
      automatic = true;
      dates = "daily";

      # Delete older generations too
      options = "--delete-older-than 14d";
    };

    # This will add each flake input as a registry
    # To make nix3 commands consistent with your flake
    registry = lib.mapAttrs (_: value: { flake = value; }) inputs;

    # This will additionally add your inputs to the system's legacy channels
    # Making legacy nix commands consistent as well, awesome!
    nixPath = lib.mapAttrsToList (key: value: "${key}=${value.to.path}") config.nix.registry;

    distributedBuilds = true;
    buildMachines = lib.mkIf (config.system.name != "nixserv") [{
      inherit (flake.nixosConfigurations.nixserv.config.networking) hostName;
      system = "x86_64-linux";
      protocl = "ssh-ng";
      sshUser = "builder";
      sshKey = config.sops.secrets.SSH_PRIVATE_KEY.path;
      supportedFeatures = [ "kvm" "nixos-test" "big-parallel" "benchmark" ];
    }];
  };
}
