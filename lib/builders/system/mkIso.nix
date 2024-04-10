{ inputs
, pkgs
, lib

, raw
, isoFormat
, ...
}: inputs.nixos-generators.nixosGenerate {
  inherit pkgs lib;
  inherit (raw) system specialArgs;

  format = isoFormat;

  modules = [
    # Pin nixpkgs to the flake input, so that the packages installed
    # come from the flake inputs.nixpkgs.url.
    # ({ ... }: { nix.registry.nixpkgs.flake = inputs.nixpkgs; })
  ] ++ raw.modules;
}
