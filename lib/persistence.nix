{ lib, config, ... }: {
  persistablePath = path:
    let
      hasOptinPersistence = config.environment.persistence ? "/persist";
    in
    "${lib.optionalString hasOptinPersistence "/persist"}${path}";
}
