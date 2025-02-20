{
  flake,
  pkgs,
  name,
  ...
}:
let
  userDirectory = "${flake}/home/${name}";
in
flake.inputs.home-manager.lib.homeManagerConfiguration {
  inherit pkgs;

  extraSpecialArgs = {
    inherit flake;
    inherit (flake) inputs outputs;
  };

  modules = [
    ({
      imports = [
        flake.inputs.stylix.homeManagerModules.stylix
      ];
    })
    (
      { lib, ... }:
      import ./userConf.nix {
        inherit
          flake
          lib
          name
          userDirectory
          ;
      }
    )
  ];
}
