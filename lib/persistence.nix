{ lib, hasPersistence, ... }: rec {
  # persistablePath = path:
  #   let
  #     hasOptinPersistence = environment.persistence ? "/persist";
  #   in
  #   "${lib.optionalString hasOptinPersistence "/persist"}${path}";

  # hasPersistence = (builtins.hasAttr "persistence" options.environment);

  persistable = path: "${lib.optionalString hasPersistence "/persist"}${path}";
    # if (hasPersistence)
    # then persistablePath path
    # else path;
}
