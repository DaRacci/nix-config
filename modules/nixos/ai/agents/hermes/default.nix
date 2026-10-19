{
  inputs,
  lib,
  importExternals ? true,
  ...
}:
let
  inherit (lib)
    mkOption
    optional
    ;
  hlib = import ./lib.nix { inherit lib; };
in
{
  imports = [
    ./platform
    ./plugins

    ./core.nix
    ./browser.nix
    ./dashboard.nix
    ./memory.nix
    ./post-start.nix
    ./scraper.nix
    ./voice.nix
  ]
  ++ optional importExternals inputs.hermes-agent.nixosModules.default;

  options.services.ai-agent.settings = mkOption {
    type = hlib.hermesConfigType;
    default = { };
    description = ''
      Hermes config to merge into `services.hermes-agent.settings`.

      This is a local option that merges correctly across feature toggles.
      The upstream `services.hermes-agent.settings` uses `lib.recursiveUpdate` for its config type,
      which replaces lists instead of concatenating them, so separate blocks would clobber each other.
      This option deep-merges with list concatenation and is emitted once as the final value of `services.hermes-agent.settings`.
    '';
  };
}
