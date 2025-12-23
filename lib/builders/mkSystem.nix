{
  self,
  inputs,

  pkgs,
  lib,

  name,
  deviceUsers,
  deviceType,
  allocations,
  ...
}:
let
  inherit (builtins) pathExists attrValues filter;
  inherit (lib)
    mkDefault
    nixosSystem
    optional
    optionals
    genAttrs
    genAttrs'
    nameValuePair
    unique
    ;
  inherit (pkgs.stdenv.hostPlatform) system;

  hostName = name;
  usersWithRoot = deviceUsers ++ [ "root" ] |> unique;
  hostDirectory = "${self}/hosts/${deviceType}/${hostName}";

  userDirectory = username: "${self}/home/${username}";
  osConfigPath = username: "${userDirectory username}/os-config.nix";
in
nixosSystem rec {
  inherit pkgs lib system;

  modules =
    (attrValues (import "${self}/modules/nixos"))
    ++ (usersWithRoot |> map osConfigPath |> filter pathExists) # Include each user's os-config.nix if it exists
    ++ [
      "${self}/modules/nixos/${deviceType}"

      (import "${self}/modules/flake/apply/system.nix" {
        inherit allocations deviceType hostName;
      })

      "${self}/hosts/shared/global"
      "${self}/hosts/${deviceType}/shared"
      hostDirectory

      {
        imports = [ inputs.disko.nixosModules.disko ];

        host = {
          inherit name system;
          device.role = deviceType;
        };

        nixpkgs.hostPlatform = pkgs.stdenv.hostPlatform.system;
      }
    ]
    ++ (optional (deviceUsers != [ ]) (
      { config, ... }:
      {
        imports = [ inputs.home-manager.nixosModules.default ];

        sops.secrets = genAttrs' deviceUsers (
          username:
          nameValuePair "USER_PASSWORD/${username}" {
            sopsFile = "${hostDirectory}/secrets.yaml";
            neededForUsers = true;
          }
        );

        users.users = genAttrs deviceUsers (username: {
          isNormalUser = mkDefault true;
          hashedPasswordFile = config.sops.secrets."USER_PASSWORD/${username}".path;
          openssh.authorizedKeys.keyFiles = [ "${userDirectory username}/id_ed25519.pub" ];
        });

        home-manager = {
          backupFileExtension = "bak";
          useUserPackages = true;
          useGlobalPkgs = true;

          extraSpecialArgs = {
            inherit self;
            inherit (self) inputs outputs;
          };

          sharedModules = optionals (!config.stylix.enable) config.stylix.homeManagerIntegration.module;
          users = genAttrs deviceUsers (
            name:
            import ./home/userConf.nix {
              inherit
                self
                lib
                name
                hostName
                allocations
                ;
              userDirectory = userDirectory name;
              user = config.users.users.${name};
            }
          );
        };
      }
    ));

  specialArgs = {
    inherit self hostDirectory;
    inherit (self) inputs outputs;
    users = deviceUsers;
  };
}
