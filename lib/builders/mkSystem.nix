{
  self,
  pkgs,
  lib,
  name,
  users ? [ ],
  deviceType,
  ...
}:
let
  hostDirectory = "${self}/hosts/${deviceType}/${name}";
in
lib.nixosSystem rec {
  inherit pkgs lib;
  inherit (pkgs.stdenv) system;

  modules =
    (builtins.attrValues (import "${self}/modules/nixos"))
    ++ [
      "${self}/hosts/shared/global"
      "${self}/hosts/${deviceType}/shared"
      hostDirectory
      (
        { inputs, ... }:
        {
          imports = [
            inputs.home-manager.nixosModules.default
            inputs.angrr.nixosModules.angrr
            inputs.disko.nixosModules.disko
          ];

          host = {
            inherit name system;
            device.role = deviceType;
          };

          home-manager = {
            useUserPackages = true;
            useGlobalPkgs = true;
          };

          system.stateVersion = "25.05";
          nixpkgs.hostPlatform = pkgs.stdenv.hostPlatform.system;
        }
      )
    ]
    ++ (lib.trivial.pipe (users ++ [ "root" ]) [
      (map (
        username:
        (import "${self}/lib/builders/home/mkSystem.nix" {
          inherit self lib pkgs;
          name = username;
          hostName = name;
          skipPassword = username == "root";
        })
      ))
    ]);

  specialArgs = {
    inherit self hostDirectory;
    inherit (self) inputs outputs;
  };
}
