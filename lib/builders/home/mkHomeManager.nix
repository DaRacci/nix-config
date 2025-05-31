{
  self,
  pkgs,
  name,
  ...
}:
let
  userDirectory = "${self}/home/${name}";
in
self.inputs.home-manager.lib.homeManagerConfiguration {
  inherit pkgs;

  extraSpecialArgs = {
    inherit self;
    inherit (self) inputs outputs;
  };

  modules = [
    {
      imports = [
        self.inputs.stylix.homeModules.stylix
      ];
    }
    (
      { lib, ... }:
      import ./userConf.nix {
        inherit
          self
          lib
          name
          userDirectory
          ;
      }
    )
  ];
}
