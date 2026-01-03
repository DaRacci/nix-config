{
  self,
  lib,

  name,
  userDirectory,
  user ? null,
  hostName ? null,
  allocations ? null,
  ...
}:
let
  inherit (lib) mkIf mkDefault optional;
  inherit (builtins) pathExists;
in
{
  home = {
    username = name;
    homeDirectory = mkDefault "/home/${name}";

    sessionPath = [ "$HOME/.local/bin" ];
  };

  sops = mkIf (user != null) {
    defaultSymlinkPath = "/run/user/${toString user.uid}/secrets";
    defaultSecretsMountPoint = "/run/user/${toString user.uid}/secrets.d";
  };

  imports = [
    "${self}/home/shared/global"
    "${userDirectory}/hm-config.nix"
  ]
  ++ (optional (allocations != null) (
    import "${self}/modules/flake/apply/home-manager.nix" {
      inherit allocations hostName name;
    }
  ))
  ++ (
    let
      hostPath = "${userDirectory}/${hostName}.nix";
    in
    optional (hostName != null && pathExists hostPath) hostPath
  );
}
