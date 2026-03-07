# The purpose of this module is to provide additional testing context for the clusters tests in the CI flake-module.
# The options in the module don't configure anything for the live systems.
{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib) type mkOption mkEnableOption;
  inherit (type) submodule attrsOf either listOf str bool functionTo;
in {
  options = {
    server.tests = {
      enable = mkEnableOption "Enable testing of this machine in the cluster tests";

      units = attrsOf (submodule ({ name, ... }: {
        options = {
          name = mkOption {
            type = str;
            default = name;
            description = ''
              The name to give to this unit test.
              This is used to enter into a subtest within the testScript of the cluster test.
            '';
          };

          testScript = mkOption {
            type = either str (functionTo str);
            description = ''
              Python code to be ran within the subtest for this unit.

              If this is a function with one argument of this nodes config.
              If this is a function with two arguments, the second argument is the entire cluster configuration.
            '';
          };
        };
      }));
    };
  };

  config = { };
}
