home:
let
  inherit (home) pkgs;
  inherit (pkgs) lib;

  # Doing this to silence the warning about collectModules being an internal function
  inherit
    (
      (import (home.options._module.specialArgs.value.inputs.nixpkgs + "/lib/modules.nix") {
        lib = lib.extend (
          _: prev: {
            trivial = prev.trivial // {
              warn = _: y: y;
            };
          }
        );
      })
    )
    collectModules
    ;
in
lib.pipe
  (collectModules ./. home.options._module.args.value.moduleType.getSubModules (
    {
      inherit (home) options;
      lib = lib.extend (_: _: { hm = home.options.lib.value; });
      specialArgs = home.options._module.specialArgs.value;
      config = home.config // {
        inherit (home.options) _module;
      };
    }
    // home.options._module.specialArgs.value
  ))
  [
    (lib.map (lib.getAttr "_file"))
    lib.unique
  ]
