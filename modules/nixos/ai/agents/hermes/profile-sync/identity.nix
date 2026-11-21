{ lib }:
let
  inherit (lib) optionalAttrs;
in
{
  compile =
    layer:
    optionalAttrs (layer ? class && layer.class != null) { inherit (layer) class; }
    // optionalAttrs (layer ? inherits && layer.inherits != null) { inherit (layer) inherits; };
}
