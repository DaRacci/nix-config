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

  inherit (raw) modules;
}
