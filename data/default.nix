{
  self,
  lib,
}:
let
  dataLib = import ./_lib.nix { inherit lib; };

  modules = {
    network = import ./network.nix { inherit self lib dataLib; };
    redis = import ./redis { inherit dataLib; };
    site = import ./site.nix { inherit dataLib; };
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
