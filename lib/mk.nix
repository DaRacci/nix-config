{ self, ... }@inputs: with inputs.nixpkgs.lib; {

  mkUserModule = { username }:
    { pkgs, config, ... }:
    let
      hostname = config.system.name;
      configuration = ../home/${username}/${hostname}.nix;
      homeDirectory = if pkgs.stdenv.isDarwin then "/Users/${username}" else "/home/${username}";
      persistenceDirectory = "/persist${homeDirectory}";
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
        persistence."${persistenceDirectory}" = {
          allowOther = true;
          directories = persistenceDirectories;
        };
      };

      imports = [
        ../home/common/global
        configuration
      ];
    };

  mkSystem = hostName: { users ? [ ], system ? "x86_64-linux" }:
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
      ] ++
      (builtins.map
        (username: { flake, config, ... }:
          let inherit (flake) inputs; in {
            imports = [ inputs.sops-nix.nixosModules.sops ];

            users.users.${username} = {
              isNormalUser = mkDefault true;
              # TODO :: Not fucking this shit
              extraGroups = [ "video" "audio" ] ++ [ "wheel" "network" "i2c" "docker" "podman" "git" "libvirtd" ];

              passwordFile = config.sops.secrets."${username}-passwd".path;
              openssh.authorizedKeys.keys = [ (builtins.readFile ../home/${username}/id_ed25519.pub) ];
            };

            sops.secrets."${username}-passwd" = {
              sopsFile = ../hosts/${hostName}/secrets.yaml;
              neededForUsers = true;
            };
          })
        users);
      specialArgs = {
        flake = self;
        inherit (self) inputs outputs;
      };
    };

  mkHome = username: { system ? "x86_64-linux", host }:
    let
      pkgs = import self.inputs.nixpkgs { inherit system; };
      homeDirectory = if pkgs.stdenv.isDarwin then "/Users/${username}" else "/home/${username}";
      persistenceDirectory = "/persist${homeDirectory}";
    in
    inputs.home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      modules = [
        ({ ... }:
          let
            hostname = host; #config.system.name;
            configuration = ../home/${username}/${hostname}.nix;
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
              persistence."${persistenceDirectory}" = {
                allowOther = true;
                directories = persistenceDirectories;
              };
            };

            imports = [
              ../home/common/global
              configuration
            ];
          })
      ];
      extraSpecialArgs = {
        flake = self;
        inherit (self) inputs outputs;
        inherit persistenceDirectory;
      };
    };
}

