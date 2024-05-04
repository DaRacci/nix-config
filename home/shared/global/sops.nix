{ flake, config, lib, ... }:
let
  inherit (lib) mkIf;
  inherit (config.home) username;

  sopsFile = "${flake}/home/${username}/secrets.yaml";
  hasSopsFile = builtins.pathExists sopsFile;

  pubKeyFile = "${flake}/home/${username}/id_ed25519.pub";
  hasPubKeyFile = builtins.pathExists pubKeyFile;
in
{
  sops = mkIf hasSopsFile {
    defaultSopsFile = "${flake}/home/${username}/secrets.yaml";
    age.sshKeyPaths = [
      config.sops.secrets.SSH_PRIVATE_KEY.path
      "${config.user.persistence.root}/.ssh/id_ed25519"
    ];

    secrets = {
      SSH_PRIVATE_KEY = {
        path = "${config.home.homeDirectory}/.ssh/id_ed25519";
      };
    };
  };

  home.file = mkIf hasPubKeyFile {
    ".ssh/id_ed25519.pub".source = "${flake}/home/${username}/id_ed25519.pub";
  };
}
