{ self, ... }@inputs: with inputs.nixpkgs.lib; rec {

  # Define the user profile in nixos.
  mkUserHome = username: hostName: { pkgs ? import inputs.nixpkgs { system = builtins.currentSystem; }
                                   , groups ? [ ]
                                   , shell ? pkgs.bashInteractive
                                   , ...
                                   }: { flake, config, ... }: {
    users.users.${username} = {
      inherit shell;
      isNormalUser = mkDefault true;

      # Only add groups that exist.
      # TODO : Move this to where these programs reside.
      extraGroups = (builtins.filter (x: builtins.elem x (builtins.attrNames config.users.groups)) [
        "video"
        "audio"
        "wheel"
        "network"
        "i2c"
        "docker"
        "podman"
        "git"
        "libvirtd"
      ] ++ groups);

      passwordFile = config.sops.secrets."${username}-passwd".path;
      openssh.authorizedKeys.keys = [ (builtins.readFile "${flake}/home/${username}/id_ed25519.pub") ];
    };

    sops.secrets."${username}-passwd" = {
      sopsFile = "${flake}/hosts/${hostName}/secrets.yaml";
      neededForUsers = true;
    };

    home-manager = {
      users.${username} = { flake, config, host, ... }: {
        home = {
          inherit username;
          homeDirectory = mkForce "/home/${username}";

          stateVersion = mkForce "23.05";
          sessionPath = [ "$HOME/.local/bin" ];
        };

        imports = [
          "${flake}/home/common/global"
          "${flake}/home/${username}/${host.name}.nix"
        ];
      };

      extraSpecialArgs = {
        flake = self;
        host = config.host;
        inherit (self) inputs outputs;
      };
    };
  };

  # Define the user profile in home-manager.
  mkHomeManagerConfiguration = username: { args ? { } }: inputs.home-manager.lib.homeManagerConfiguration {
    pkgs = import inputs.nixpkgs { system = builtins.currentSystem; };

    modules = [
      ({ ... }: {
        home = {
          inherit username;
          homeDirectory = "/home/${username}";

          stateVersion = "23.05";
          sessionPath = [ "$HOME/.local/bin" ];
        };
      })
      "${self}/home/common/global"
    ] ++ optional ((builtins.hasAttr "host" args) && args.host.name != null) [
      "${self}/home/${username}/${args.host.name}.nix"
    ];

    extraSpecialArgs = {
      flake = self;
      inherit (self) inputs outputs;
    } // args;
  };

  # Define the system configuration in nixos.
  mkSystemConfiguration = hostName: { users ? { }
                                    , system ? inputs.flake-utils.lib.system.x86_64-linux
                                    }: nixosSystem {
    inherit system;

    modules = [
      "${self}/hosts/common/global"
      "${self}/hosts/${hostName}"

      ({ ... }: {
        imports = [ inputs.home-manager.nixosModule ];

        host.name = hostName;
        passthru.enable = false; # Why does build break without this?

        system.stateVersion = "23.05";
      })
    ] ++ (builtins.attrValues (builtins.mapAttrs (username: value: (mkUserHome username hostName value)) users));

    specialArgs = {
      flake = self;
      inherit (self) inputs outputs;
    };
  };
}
