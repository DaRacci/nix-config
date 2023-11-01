{ self, ... }@inputs: with inputs.nixpkgs.lib; rec {

  # mkUserHome = username: { groups ? lib.mkDefault [ ]
  #                        ,
  #                        }: { };

  mkHomeManagerConfiguration = username: {}: { pkgs, ... }: {
    home = {
      inherit username;

      imports = [
        "${self}/home/common/global"
        "${self}/home/${username}"
      ];
    };
  };

  mkSystemConfiguration = hostName: { users ? [ ]
                                    , system ? inputs.systems.X86_64-linux
                                    }: nixosSystem {
    inherit system;

    modules = [
      "${self}/hosts/common/global"
      "${self}/hosts/${hostName}"

      ({ ... }: {
        system.name = hostName;
        networking.hostName = hostName;
        passthru.enable = false; # Why does build break without this?
      })
    ];
  };

  mkSystemUser = username: { } {
    isNormalUser = mkDefault true;
    shell = pkgs.nushell;
    # TODO :: Not fucking this shit
    extraGroups = [ "video" "audio" "wheel" "network" "i2c" "docker" "podman" "git" "libvirtd" ];

    passwordFile = config.sops.secrets."${username}-passwd".path;
    openssh.authorizedKeys.keys = [ (builtins.readFile ../home/${username}/id_ed25519.pub) ];
  };
}
