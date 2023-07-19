{ inputs, outputs, lib, config, ... }: {
  nixpkgs = {
    overlays = builtins.attrValues outputs.overlays;
    config.allowUnfree = true;
    config.allowUnfreePredicate = _: true;
  };

  nix = {
    settings = {
      trusted-users = [ "root" "@wheel" ];
      auto-optimise-store = lib.mkDefault true;
      experimental-features = [ "nix-command" "flakes" "repl-flake" ];
      system-features = [ "kvm" "big-parallel" "nixos-test" ];
    };

    gc = {
      automatic = true;
      dates = "daily";
      # Delete older generations too
      options = "--delete-older-than 7d";
    };

    # This will add each flake input as a registry
    # To make nix3 commands consistent with your flake
    registry = lib.mapAttrs (_: value: { flake = value; }) inputs;

    # This will additionally add your inputs to the system's legacy channels
    # Making legacy nix commands consistent as well, awesome!
    nixPath = lib.mapAttrsToList (key: value: "${key}=${value.to.path}") config.nix.registry;
  };
}
