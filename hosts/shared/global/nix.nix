{ inputs, lib, config, ... }: {
  nix = {
    # nix.package = pkgs.lix;

    settings = {
      trusted-users = [ "root" "@wheel" ];
      auto-optimise-store = lib.mkForce true;
      experimental-features = [ "nix-command" "flakes" ];
      system-features = [ "kvm" "big-parallel" "nixos-test" ];

      extra-substituters = [
        "https://nix-community.cachix.org"
        "https://racci.cachix.org"
        "https://hyprland.cachix.org"
        "https://anyrun.cachix.org"
      ];
      extra-trusted-public-keys = [
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "racci.cachix.org-1:Kl4opLxvTV9c77DpoKjUOMLDbCv6wy3GVHWxB384gxg="
        "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
        "anyrun.cachix.org-1:pqBobmOjI7nKlsUMV25u9QHa9btJK65/C8vnO3p346s="
      ];
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
