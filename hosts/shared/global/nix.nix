{ inputs, lib, config, ... }:
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

    raccicachixorg = {
      url = "https://racci.cachix.org";
      key = "racci.cachix.org-1:Kl4opLxvTV9c77DpoKjUOMLDbCv6wy3GVHWxB384gxg=";
    };

    hyprlandcachixorg = {
      url = "https://hyprland.cachix.org";
      key = "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc=";
    };

    anyruncachixorg = {
      url = "https://anyrun.cachix.org";
      key = "anyrun.cachix.org-1:pqBobmOjI7nKlsUMV25u9QHa9btJK65/C8vnO3p346s=";
    };
  };
in
{
  nix = {
    # nix.package = pkgs.lix;

    settings = rec {
      trusted-users = [ "root" "@wheel" ];
      auto-optimise-store = lib.mkForce true;
      experimental-features = [ "nix-command" "flakes" ];

      substituters = map (sub: sub.url) (lib.attrValues caches);
      trusted-substituters = substituters;
      trusted-public-keys = map (sub: sub.key) (lib.attrValues caches);
    };

    # TODO :: Ssh Serve store
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
  };
}
