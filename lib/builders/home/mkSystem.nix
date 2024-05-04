{ self

, name
, groups ? [ ]
, hostName ? null
, ...
}: { flake, config, pkgs, lib, hostDirectory, ... }:
let
  inherit (lib) mkDefault mkForce optional;
  userDirectory = "${flake}/home/${name}";
  user = config.users.users.${name};
  publicKey = pkgs.writeTextFile {
    name = "${name}_ed25519.pub";
    text = "${userDirectory}/id_ed25519.pub";
  };

  osConfigPath = "${userDirectory}/os-config.nix";
in
{
  imports = optional (builtins.pathExists osConfigPath) osConfigPath;

  users.users.${name} = {
    isNormalUser = mkDefault true;

    # Only add groups that exist.
    # TODO : Move this to where these programs reside.
    extraGroups = builtins.filter (x: builtins.elem x (builtins.attrNames config.users.groups)) [
      "video"
      "audio"
      "wheel"
      "network"
      "i2c"
      "docker"
      "podman"
      "git"
      "libvirtd"
    ] ++ groups;

    hashedPasswordFile = config.sops.secrets."${name}-passwd".path;
    openssh.authorizedKeys.keyFiles = [ publicKey ];
  };

  sops.secrets."${name}-passwd" = {
    sopsFile = "${hostDirectory}/secrets.yaml";
    neededForUsers = true;
  };

  home-manager = {
    extraSpecialArgs = {
      flake = self;
      inherit (self) inputs outputs;
    };

    users.${name} = { flake, ... }: {
      home = {
        username = name;
        homeDirectory = mkDefault "/home/${name}";

        stateVersion = mkForce "23.11";
        sessionPath = [ "$HOME/.local/bin" ];
      };

      sops = {
        defaultSymlinkPath = "/run/user/${toString user.uid}/secrets";
        defaultSecretsMountPoint = "/run/user/${toString user.uid}/secrets.d";
      };

      imports = builtins.attrValues (import "${flake}/modules/home-manager") ++ [
        "${flake}/home/shared/global"
      ] ++ (let hostPath = "${userDirectory}/${hostName}.nix"; in lib.optional (hostName != null && builtins.pathExists hostPath) hostPath);
    };
  };
}
