{ lib, ... }:
{
  # persistablePath = path:
  #   let
  #     hasOptinPersistence = environment.persistence ? "/persist";
  #   in
  #   "${lib.optionalString hasOptinPersistence "/persist"}${path}";

  # hasPersistence = (builtins.hasAttr "persistence" options.environment);

  persistable = config: path: "${lib.optionalString config.host.persistence.enable "/persist"}${path}";
}
