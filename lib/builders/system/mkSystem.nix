{ inputs
, raw
, ...
}: inputs.nixpkgs.lib.nixosSystem raw
