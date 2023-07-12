{ self, nixpkgs, home-manager, ... }@inputs: {

  mkNixosConfig =
    { hostname
    , system ? "x86_64-linux"
    , extraModules ? [ ]
    }: {
      nixosConfigurations.${hostname} = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [ ../hosts/${hostname} ] ++ extraModules;
        specialArgs = { flake = self; };
      };
    };

  mkHomeConfig =
    { hostname
    , username
    , system ? "x86_64-linux"
    , configuration ? ./home/${username}/${hostname}.nix
    , homeDirectory ? "/home/${username}"
    , extraGroups ? [ ]
    , persistenceDirectory ? "/persist/${homeDirectory}"
    , persistenceDirectories ? [
        "Documents"
        "Downloads"
        "Pictures"
        "Videos"
        "Music"
        "Templates"
        ".local/share/keyrings"
      ]
    }:
    let
      pkgs = import nixpkgs { inherit system; };

      # ifTheyExist = groups: builtins.filter (group: builtins.hasAttr group config.users.groups) groups;

      hmModule = { ... }: {
        home = {
          inherit username homeDirectory;
          stateVersion = "23.05";
          sessionPath = [ "$HOME/.local/bin" ];
          home.persist."${persistenceDirectory}".directories = persistenceDirectories;
        };

        imports = [ ./home/common/global configuration ];
      };
    in
    {
      nixosConfigurations.${hostname} = {
        modules = [
          ({ ... }: {
            users.users.${username} = {
              isNormalUser = nixpkgs.lib.mkDefault true;
              extraGroups = [ "video" "audio" ];
              # extraGroups = ifTheyExist ([ "video" "audio" ] ++ extraGroups);
            };

            home-manager.users.${username} = hmModule;
          })
        ];
      };

      homeConfigurations.${hostname} = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [ hmModule ];
        extraSpecialArgs = {
          inherit persistenceDirectory;
          flake = self;
        };
      };
    };
}
