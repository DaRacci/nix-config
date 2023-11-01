{ self, ... }@inputs: with inputs.nixpkgs.lib; rec {

  # mkUserModule = { username }:
  #   { pkgs, config, ... }:
  #   let
  #     hostname = config.system.name;
  #     configuration = ../home/${username}/${hostname}.nix;
  #     homeDirectory = if pkgs.stdenv.isDarwin then "/Users/${username}" else "/home/${username}";
  #     persistenceDirectory = "/persist${homeDirectory}";
  #     persistenceDirectories = [
  #       "Documents"
  #       "Downloads"
  #       "Pictures"
  #       "Videos"
  #       "Music"
  #       "Templates"
  #       ".local/share/keyrings"
  #     ];
  #   in
  #   {
  #     home = {
  #       inherit username homeDirectory;
  #       stateVersion = "23.05";
  #       sessionPath = [ "$HOME/.local/bin" ];
  #       persistence."${persistenceDirectory}" = {
  #         allowOther = true;
  #         directories = persistenceDirectories;
  #       };
  #     };

  #     imports = [
  #       ../home/common/global
  #       configuration
  #     ];
  #   };

  mkSystem = hostName: { users ? [ ], system ? "x86_64-linux", persistenceType ? "none" }:
    nixosSystem {
      inherit system;
      modules = [
        ../hosts/common/global
        ../hosts/${hostName}
        ({ ... }: {
          system.name = hostName;
          networking.hostName = hostName;
          passthru.enable = false; # Why does build break without this?
        })
      ] ++ (
        if persistenceType == "none" then [ ]
        else if persistenceType == "tmpfs"
        then [ ../hosts/common/optional/ephemeral-tmpfs.nix ]
        else if persistenceType == "btrfs"
        then [ ../hosts/common/optional/ephemeral-btrfs.nix ]
        else throw "Unknown persistence type: ${persistenceType}"
      ) ++
      (builtins.map
        (username: { flake, config, pkgs, ... }:
          let inherit (flake) inputs;homeDirectory = if pkgs.stdenv.isDarwin then "/Users/${username}" else "/home/${username}"; persistenceDirectory = "/persist${homeDirectory}"; in {
            imports = [ inputs.home-manager.nixosModule ];

            users.users.${username} = {
              isNormalUser = mkDefault true;
              shell = pkgs.nushell;
              # TODO :: Not fucking this shit
              extraGroups = [ "video" "audio" "wheel" "network" "i2c" "docker" "podman" "git" "libvirtd" ];

              passwordFile = config.sops.secrets."${username}-passwd".path;
              openssh.authorizedKeys.keys = [ (builtins.readFile ../home/${username}/id_ed25519.pub) ];
            };

            sops.secrets."${username}-passwd" = {
              sopsFile = ../hosts/${hostName}/secrets.yaml;
              neededForUsers = true;
            };

            home-manager.extraSpecialArgs = {
              flake = self;
              hasPersistence = persistenceType != "none";
              inherit (self) inputs outputs;
              inherit persistenceDirectory;
            };

            home-manager.users."${username}" = ({ pkgs, ... }:
              let
                configuration = ../home/${username}/${hostName}.nix;
                persistenceDirectories = [
                  "Documents"
                  "Downloads"
                  "Pictures"
                  "Videos"
                  "Music"
                  "Templates"
                  ".local/share/keyrings"
                ];
              in
              {
                home = {
                  inherit username homeDirectory;
                  stateVersion = "23.05";
                  sessionPath = [ "$HOME/.local/bin" ];
                } // optionalAttrs (persistenceType != "none") {
                  persistence."${persistenceDirectory}" = {
                    allowOther = true;
                    directories = persistenceDirectories;
                  };
                };

                imports = [
                  ../home/common/global
                  configuration
                ];
              });
          })
        users);
      specialArgs = {
        flake = self;
        inherit (self) inputs outputs;
        hasPersistence = persistenceType != "none";
      };
    };

  # mkHome = username: { system ? "x86_64-linux", host }:
  #   let
  #     pkgs = import self.inputs.nixpkgs { inherit system; };
  #   in
  #   inputs.home-manager.lib.homeManagerConfiguration {
  #     inherit pkgs;
  #     modules = [

  #     ];
  #     extraSpecialArgs = {
  #       flake = self;
  #       inherit (self) inputs outputs;
  #       inherit persistenceDirectory;
  #     };
  #   };
}

