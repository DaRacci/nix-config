{
  config,
  lib,
  ...
}:
let
  inherit (lib) mkIf;
  cfg = config.security;
in
{
  config = mkIf cfg.enable {
    programs.tirith = {
      enable = lib.mkForce true;
      policy = {
        version = 1;
        fail_mode = "open";
        allow_bypass_env = true;
      };
    };
  };
}
