{ inputs
, raw
, isoFormat
, ...
}: inputs.nixos-generators.nixosGenerate {
  inherit (raw) system modules specialArgs;
  format = isoFormat;
}
