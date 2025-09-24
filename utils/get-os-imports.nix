system:
let
  inherit (system) lib;

  # Doing this to silence the warning about collectModules being an internal function
  inherit
    (
      (import (system._module.specialArgs.self.inputs.nixpkgs + "/lib/modules.nix") {
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
collectModules ./. system.type.getSubModules (
  {
    inherit (system) lib options;
    inherit (system._module) specialArgs;
    config = system.config // {
      inherit (system) _module;
    };
  }
  // system._module.specialArgs
)
|> lib.getAttr "modules"
|> lib.map (lib.getAttr "_file")
|> lib.unique
