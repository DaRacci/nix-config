{
  flake,
  pkgs,
  lib,
  name,
  users ? [ ],
  deviceType,
  ...
}:
let
  hostDirectory = "${flake}/hosts/${deviceType}/${name}";
in
rec {
  inherit pkgs lib;
  inherit (pkgs.stdenv) system;

  modules =
    (builtins.attrValues (import "${flake}/modules/nixos"))
    ++ [
      "${flake}/hosts/shared/global"
      "${flake}/hosts/${deviceType}/shared"
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
          nixpkgs.hostPlatform = pkgs.system;
        }
      )
    ]
    ++ (lib.trivial.pipe (users ++ [ "root" ]) [
      (map (
        username:
        (import "${flake}/lib/builders/home/mkSystem.nix" {
          inherit flake lib pkgs;
          name = username;
          hostName = name;
          skipPassword = username == "root";
        })
      ))
    ]);

  specialArgs = {
    inherit flake hostDirectory;
    inherit (flake) inputs outputs;
  };
}
