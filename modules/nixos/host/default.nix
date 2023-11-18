{ flake, config, lib, ... }: with lib; let cfg = config.host; in {
  options.host = {
    name = mkOption {
      type = types.str;
      default = throw "host.name is required";
      description = "The name of the host.";
    };
  };

  config = { };
}
