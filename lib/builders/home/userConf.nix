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

    sessionPath = [ "$HOME/.local/bin" ];
    stateVersion = "25.05";
  };

  sops = lib.mkIf (user != null) {
    defaultSymlinkPath = "/run/user/${toString user.uid}/secrets";
    defaultSecretsMountPoint = "/run/user/${toString user.uid}/secrets.d";
  };

  imports =
    [
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
