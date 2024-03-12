{ lib, outputs, pkgs, host, ... }: {
  nixpkgs = {
    overlays = builtins.attrValues outputs.overlays.${host.system};
    config = {
      allowUnfree = true;
      allowUnfreePredicate = (_: true);
      permittedInsecurePackages = [ ];
    };
  };

  nix = {
    package = lib.mkDefault pkgs.nix;
    settings = {
      experimental-features = [ "nix-command" "flakes" "repl-flake" ];
      warn-dirty = false;
    };
  };
}
