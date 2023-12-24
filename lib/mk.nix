{ self, ... }@inputs: with inputs.nixpkgs.lib; rec {

  # Define the user profile in nixos.
  mkUserHome = username: hostName: { pkgs ? import inputs.nixpkgs { system = builtins.currentSystem; }
                                   , extraHome ? { ... }: { }
                                   , groups ? [ ] #((import extraHome { }).groups) or [ ]
                                   , shell ? ((extraHome { inherit pkgs; }).shell)
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

      hashedPasswordFile = config.sops.secrets."${username}-passwd".path;
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

          stateVersion = mkForce "23.11";
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

          stateVersion = "23.11";
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

  mkRawConfiguration = hostName: { users ? { }
                                 , role
                                 , system ? inputs.flake-utils.lib.system.x86_64-linux
                                 }:
    let
      hostDir =
        let
          opt1 = "${self}/hosts/${hostName}";
          opt2 = "${self}/hosts/servers/${hostName}";
        in
        if (builtins.pathExists opt1) then opt1 else opt2;
    in
    {
      inherit system;

      modules = [
        "${self}/hosts/common/global"
        "${self}/hosts/roles/common"
        "${self}/hosts/roles/${role}"
        "${hostDir}"

        ({ ... }: {
          imports = [ inputs.home-manager.nixosModule ];

          host.name = hostName;
          passthru.enable = false; # Why does build break without this?

          system.stateVersion = "23.11";
        })
      ] ++ (builtins.attrValues (builtins.mapAttrs (username: value: (mkUserHome username hostName value)) users));

      specialArgs = {
        flake = self;
        inherit hostDir;
        inherit (self) inputs outputs;
      };
    };

  # Define the system configuration in nixos.
  mkSystemConfiguration = hostName: { users ? { }
                                    , role
                                    , system ? inputs.flake-utils.lib.system.x86_64-linux
                                    }: nixosSystem (mkRawConfiguration hostName { inherit users role system; });
  #   inherit system;

  #   modules = [
  #     "${self}/hosts/common/global"

  #     (if (builtins.pathExists "${self}/hosts/${hostName}")
  #     then "${self}/hosts/${hostName}"
  #     else if (builtins.pathExists "${self}/hosts/servers/${hostName}")
  #     then "${self}/hosts/servers/${hostName}"
  #     else throw "No host configuration found for ${hostName}.")

  #     ({ ... }: {
  #       imports = [ inputs.home-manager.nixosModule ];

  #       host.name = hostName;
  #       passthru.enable = false; # Why does build break without this?

  #       system.stateVersion = "23.11";
  #     })
  #   ] ++ (builtins.attrValues (builtins.mapAttrs (username: value: (mkUserHome username hostName value)) users));

  #   specialArgs = {
  #     flake = self;
  #     inherit (self) inputs outputs;
  #   };
  # };
}
