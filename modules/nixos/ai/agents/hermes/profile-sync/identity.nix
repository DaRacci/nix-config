{ lib }:
let
  inherit (lib) optionalAttrs;
in
{
  # `class` and `inherits` are declared on the profile and class submodules rather than in the
  # shared vocabulary, so this area is the only place that carries them into the compiled manifest.
  compile =
    layer:
    optionalAttrs (layer ? class && layer.class != null) { inherit (layer) class; }
    // optionalAttrs (layer ? inherits && layer.inherits != null) { inherit (layer) inherits; };
}
