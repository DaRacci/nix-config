{ flake, config, ... }:
let
  inherit (config.home) username;
in
{
  sops = {
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

  home.file = {
    ".ssh/id_ed25519.pub".source = "${flake}/home/${username}/id_ed25519.pub";
  };
}
