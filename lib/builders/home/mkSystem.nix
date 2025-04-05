{
  flake,
  name,
  groups ? [ ],
  hostName ? null,
  skipPassword ? false,
  ...
}:
{
  config,
  lib,
  hostDirectory,
  ...
}:
let
  inherit (lib)
    mkIf
    mkDefault
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
        "kvm"
        "adbusers"
      ]
      ++ groups;

    hashedPasswordFile = mkIf (!skipPassword) config.sops.secrets."USER_PASSWORD/${name}".path;
    openssh.authorizedKeys.keyFiles = mkIf (!skipSSHKey) [ sourceSSHKey ];
  };

  sops.secrets."USER_PASSWORD/${name}" = mkIf (!skipPassword) {
    sopsFile = "${hostDirectory}/secrets.yaml";
    neededForUsers = true;
  };

  home-manager = {
    backupFileExtension = "bak";

    extraSpecialArgs = {
      inherit flake;
      inherit (flake) inputs outputs;
    };

    users.${name} = import ./userConf.nix {
      inherit
        flake
        lib
        name
        user
        hostName
        userDirectory
        ;
    };
  };
}
