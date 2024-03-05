{ lib, host, ... }: {
  # persistablePath = path:
  #   let
  #     hasOptinPersistence = environment.persistence ? "/persist";
  #   in
  #   "${lib.optionalString hasOptinPersistence "/persist"}${path}";

  # hasPersistence = (builtins.hasAttr "persistence" options.environment);

  persistable = path: "${lib.optionalString host.persistence.enable "/persist"}${path}";
}
