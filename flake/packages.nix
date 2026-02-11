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
    {
      packages = lib.mkMerge [
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

        (import "${self}/docs" {
          inherit
            self
            system
            pkgs
            lib
            ;
          inputs = config.partitions.docs.extraInputs;
        })
      ];
    };
}
