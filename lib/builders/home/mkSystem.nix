{
  self,
  name,
  groups ? [ ],
  hostName ? null,
  skipPassword ? false,
  ...
}:
{
  flake,
  config,
  lib,
  hostDirectory,
  ...
}:
let
  inherit (lib)
    mkIf
    mkDefault
    mkForce
    optional
    ;
  userDirectory = "${flake}/home/${name}";
  user = config.users.users.${name};
  sourceSSHKey = "${userDirectory}/id_ed25519.pub";
  skipSSHKey = !(builtins.pathExists sourceSSHKey);

  osConfigPath = "${userDirectory}/os-config.nix";
in
{
  imports = optional (builtins.pathExists osConfigPath) osConfigPath;

  users.users.${name} = {
    isNormalUser = mkDefault true;

    # Only add groups that exist.
    # TODO : Move this to where these programs reside.
    extraGroups =
      builtins.filter (x: builtins.elem x (builtins.attrNames config.users.groups)) [
        "video"
        "audio"
        "wheel"
        "network"
        "i2c"
        "docker"
        "podman"
        "git"
        "libvirtd"
        "adbusers"
      ]
      ++ groups;

    hashedPasswordFile = mkIf (!skipPassword) config.sops.secrets."${name}-passwd".path;
    openssh.authorizedKeys.keyFiles = mkIf (!skipSSHKey) [ sourceSSHKey ];
  };

  sops.secrets."${name}-passwd" = mkIf (!skipPassword) {
    sopsFile = "${hostDirectory}/secrets.yaml";
    neededForUsers = true;
  };

  home-manager = {
    backupFileExtension = "bak";

    extraSpecialArgs = {
      flake = self;
      inherit (self) inputs outputs;
    };

    users.${name} =
      { flake, ... }:
      {
        home = {
          username = name;
          homeDirectory = mkDefault "/home/${name}";

          stateVersion = mkForce "24.05";
          sessionPath = [ "$HOME/.local/bin" ];
        };

        sops = {
          defaultSymlinkPath = "/run/user/${toString user.uid}/secrets";
          defaultSecretsMountPoint = "/run/user/${toString user.uid}/secrets.d";
        };

        imports =
          builtins.attrValues (import "${flake}/modules/home-manager")
          ++ [
            "${flake}/home/shared/global"
            "${userDirectory}/global.nix"
          ]
          ++ (
            let
              hostPath = "${userDirectory}/${hostName}.nix";
            in
            lib.optional (hostName != null && builtins.pathExists hostPath) hostPath
          );
      };
  };
}
