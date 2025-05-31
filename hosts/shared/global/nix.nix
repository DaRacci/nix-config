{
  self,
  pkgs,
  lib,
  config,
  ...
}:
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
      url = "https://cache.racci.dev/global";
      key = "global:OKNSxDYKp8Q8Tr5/5Bc7CYVSfvdFQV0dMhpG0fOAG0k=";
    };
  };
in
{
  nix = {
    settings = rec {
      trusted-users = [
        "root"
        "@wheel"
      ];
      auto-optimise-store = lib.mkForce true;
      experimental-features = [
        "nix-command"
        "flakes"
        "pipe-operator"
      ];

      substituters = map (sub: sub.url) (lib.attrValues caches);
      trusted-substituters = substituters;
      trusted-public-keys = map (sub: sub.key) (lib.attrValues caches);
    };

    gc = {
      automatic = true;
      dates = "daily";
      persistent = true;

      # Delete older generations too
      # TODO :: Is there a way to keep the last 2 generations?
      # maybe also clean generations not only if 14 days old but if unused for 14 days
      options = "--delete-older-than 14d";
    };

    # This will add each flake input as a registry
    # To make nix3 commands consistent with your flake
    # registry = lib.mapAttrs (_: value: { flake = value; }) inputs;

    # This will additionally add your inputs to the system's legacy channels
    # Making legacy nix commands consistent as well, awesome!
    # nixPath = lib.mapAttrsToList (key: value: "${key}=${value.to.path}") config.nix.registry;
  };

  sops.secrets.CACHE_PUSH_KEY = {
    sopsFile = "${self}/hosts/secrets.yaml";
    restartUnits = [ "attic-watch-store.service" ];
  };

  services.angrr = {
    enable = true;
    period = "7days";
  };

  systemd.services.attic-watch-store = {
    description = "Watch nix store for attic";
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];

    unitConfig = {
      StartLimitInterval = 0;
    };

    serviceConfig = {
      RestartSec = 1;
      Restart = "on-failure";
    };

    script = lib.getExe (
      pkgs.writeShellApplication {
        name = "attic-watch-store";
        runtimeInputs = [ pkgs.attic-client ];
        text = ''
          JWT=$(cat ${config.sops.secrets.CACHE_PUSH_KEY.path})
          attic login build-auto-push ${caches.cacheraccidev.url} "$JWT" || exit 1
          attic watch-store build-auto-push:global
        '';
      }
    );
  };
}
