{
  lib,
}:
let
  policyModule = import ../../modules/nixos/ai/agents/hermes/profile-sync/policy.nix { inherit lib; };

  inherit (lib)
    concatLists
    hasAttrByPath
    optional
    splitString
    ;

  # A policy that declares a class chain, so a compile that drops an identity field shows up here
  # rather than on a live profile.
  fixture = {
    defaults = {
      settings.feature.enabled = true;
      env."inherit" = [ "FLEET_KEY" ];
      lock.env = [ "FLEET_KEY" ];
    };

    classes = {
      base.env.set.BASE_FLAG = "base";
      work = {
        inherits = "base";
        env.set.WORK_FLAG = "work";
      };
    };

    profiles = {
      worker = {
        class = "work";
        settings.team = "work";
      };
      unclassed.settings.team = "fleet";
    };

    links = {
      default = [
        {
          target = ".exampleconfig";
          source = "/home/hermes/.exampleconfig";
        }
      ];
      classes.work.exclude = [ ".exampleconfig" ];
    };
  };

  cfg =
    (lib.evalModules {
      modules = [
        { inherit (policyModule) options; }
        fixture
      ];
    }).config;

  manifest = policyModule.compile cfg;

  at = path: lib.attrByPath (splitString "." path) null manifest;
  has = path: hasAttrByPath (splitString "." path) manifest;

  # One entry per manifest assertion that does not hold.
  problems = concatLists [
    (optional (at "profiles.worker.class" != "work") "profiles.worker.class is not in the manifest")
    (optional (at "classes.work.inherits" != "base") "classes.work.inherits is not in the manifest")
    (optional (has "profiles.unclassed.class") "profiles.unclassed carries a class it never declared")
    (optional (has "classes.base.inherits") "classes.base carries an inherits it never declared")
    (optional (at "profiles.worker.settings.team" != "work") "profiles.worker.settings did not compile")
    (optional (at "classes.base.env.set.BASE_FLAG" != "base") "classes.base.env did not compile")
    (optional (at "defaults.settings.feature.enabled" != true) "defaults.settings did not compile")
    (optional (at "links.classes.work.exclude" != [ ".exampleconfig" ]) "links did not compile")
  ];
in
{
  inherit problems;
}
