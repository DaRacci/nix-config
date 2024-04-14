{ self
, inputs
, pkgs
, lib

, name
, users ? [ ]
, deviceType
, ...
}:
let
  hostDirectory = "${self}/hosts/${deviceType}/${name}";
in
rec {
  inherit pkgs lib;
  inherit (pkgs.stdenv) system;

  modules = [
    ({ ... }: {
      imports = builtins.attrValues (import "${self}/modules/nixos");
    })
    ({ ... }: {
      imports = [
        inputs.nixos-generators.nixosModules.all-formats
      ];

      nixpkgs.hostPlatform = pkgs.system;
    })

    "${self}/hosts/shared/global"
    "${self}/hosts/${deviceType}/shared"
    hostDirectory

    ({ inputs, ... }: {
      imports = [
        inputs.home-manager.nixosModule
        inputs.nixos-generators.nixosModules.all-formats
      ];

      host = {
        inherit name system;
        device.role = deviceType;
      };

      # home-manager.useUserPackages = true;
      home-manager.useGlobalPkgs = true;

      # passthru.enable = false; # Why does build break without this?
      system.stateVersion = "23.11";
    })
  ] ++ (builtins.map
    (username: (import "${self}/lib/builders/home/mkSystem.nix" {
      inherit self lib pkgs;
      name = username;
      hostName = name;
    }))
    users);

  specialArgs = {
    flake = self;
    inherit hostDirectory;
    inherit (self) inputs outputs;
  };
}
