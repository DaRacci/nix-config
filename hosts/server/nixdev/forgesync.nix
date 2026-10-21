{
  inputs,
  config,
  lib,
  importExternals ? true,
  ...
}:
let
  inherit (lib) optional;

  sopsPlaceholder = config.sops.placeholder;
in
{
  imports = optional importExternals inputs.forgesync.nixosModules.default;

  sops = {
    secrets = {
      "FORGESYNC/SOURCE_TOKEN" = { };
      "FORGESYNC/TARGET_TOKEN" = { };
      "FORGESYNC/MIRROR_TOKEN" = { };
    };
    templates.FORGESYNC_ENV.content = ''
      SOURCE_TOKEN=${sopsPlaceholder."FORGESYNC/SOURCE_TOKEN"}
      TARGET_TOKEN=${sopsPlaceholder."FORGESYNC/TARGET_TOKEN"}
      MIRROR_TOKEN=${sopsPlaceholder."FORGESYNC/MIRROR_TOKEN"}
    '';
  };

  services.forgesync = {
    enable = true;

    jobs = {
      github = {
        source = "https://codeberg.org/api/v1";
        target = "github";
        secretFile = config.sops.templates.FORGESYNC_ENV.path;

        settings = {
          remirror = true;

          feature = [
            "issues"
            "pull-requests"
          ];

          #TODO: Remove exclusions
          # Ignore these for now since I use them primarily on github rn for actions, pr reviews etc.
          exclude = [
            "nix-config"
            "infra"
          ];

          on-commit = true;
          mirror-interval = "8h0m0s";

          include-forks = false;
          include-private = false;
        };

        timerConfig = {
          OnCalendar = "daily";
          Persistent = true;
          RandomizedDelaySec = "5min";
        };
      };
    };
  };
}
