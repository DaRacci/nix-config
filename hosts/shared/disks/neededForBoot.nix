{
  config,
  lib,

  ...
}:
let
  withImpermanence =
    config.environment.persistence ? "/persist" && config.environment.persistence."/persist".enable;
in
{
  fileSystems = {
    "/persist" = lib.mkIf withImpermanence { neededForBoot = true; };
    "/nix".neededForBoot = true;
  };
}
