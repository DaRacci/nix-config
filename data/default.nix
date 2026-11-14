{ lib }:
let
  v = import ./_lib.nix { inherit lib; };

  modules = {
    network = import ./network.nix { inherit v; };
    redis = import ./redis { inherit v; };
    site = import ./site.nix { inherit v; };
  };

  data =
    assert lib.assertMsg (lib.all (module: module ? data && module ? validate) (
      builtins.attrValues modules
    )) "data modules must export `data` and `validate`";
    lib.mapAttrs (_: module: module.data) modules;

  validate =
    lib: data:
    lib.concatLists (
      lib.mapAttrsToList (
        name: module:
        map (assertion: assertion // { message = "data.${name}: ${assertion.message}"; }) (
          module.validate lib data
        )
      ) modules
    );
in
{
  inherit data validate;
}
