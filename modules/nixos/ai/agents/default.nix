{
  lib,
  ...
}:
let
  inherit (lib) mkEnableOption;
in
{
  imports = [ ./hermes ];

  options.services.ai-agent.enable = mkEnableOption "autonomous AI Agent service";
}
