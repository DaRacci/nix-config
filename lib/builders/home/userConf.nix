{
  flake,
  lib,
  name,
  userDirectory,
  user ? null,
  hostName ? null,
  ...
}:
{
  home = {
    username = name;
    homeDirectory = lib.mkDefault "/home/${name}";

    stateVersion = lib.mkForce "25.05";
    sessionPath = [ "$HOME/.local/bin" ];
  };

  sops = lib.mkIf (user != null) {
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
}
