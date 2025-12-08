{
  self,
  inputs,
  ...
}:
{
  perSystem =
    { pkgs, lib, ... }:
    {
      packages = import "${self}/pkgs" { inherit inputs pkgs lib; };
    };
}
