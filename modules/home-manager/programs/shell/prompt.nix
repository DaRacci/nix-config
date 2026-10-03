{
  config,
  lib,
  ...
}:
let
  inherit (lib) mkIf;
  cfg = config.programSets.shell;
in
{
  config = mkIf cfg.enable {
    programs.starship = {
      enable = true;
      settings = { };
    };
  };
}
