{
  self,
  inputs,
  config,
  ...
}:
{
  perSystem =
    {
      pkgs,
      lib,
      system,
      ...
    }:
    let
      rumdl = import "${self}/flake/dev/rumdl.nix" { inherit pkgs; };
    in
    {
      packages = lib.mkMerge [
        {
          rumdl-config = rumdl.config;
          rumdl = rumdl.wrapper;
        }
        (import "${self}/pkgs" {
          inherit
            self
            inputs
            pkgs
            lib
            ;
        })
        (import "${self}/flake/ci/scripts" { inherit inputs pkgs lib; })
        (import "${self}/flake/dev/scripts" { inherit inputs pkgs lib; })

        (
          import "${self}/docs" {
            inherit
              self
              system
              pkgs
              lib
              ;
            inputs = config.partitions.docs.extraInputs;
          }
          |> lib.filterAttrs (_: v: lib.isDerivation v)
        )
      ];
    };
}
