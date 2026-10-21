{
  self,
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib)
    escapeShellArgs
    getExe
    mkIf
    optionals
    ;
  inherit (config.home) username;

  sopsFile = "${self}/home/${username}/secrets.yaml";
  hasSopsFile = builtins.pathExists sopsFile;

  pubKeyFile = "${self}/home/${username}/id_ed25519.pub";
  hasPubKeyFile = builtins.pathExists pubKeyFile;

  sshToAgeOutputDir = "${config.xdg.configHome}/sops/age";
  sshToAgeCommand = escapeShellArgs (
    [
      (getExe pkgs.ssh-to-age-keys)
      sshToAgeOutputDir
      "${config.user.persistence.root}/.ssh/id_ed25519"
    ]
    ++ optionals hasSopsFile [ config.sops.secrets.SSH_PRIVATE_KEY.path ]
  );
in
{
  sops = mkIf hasSopsFile {
    defaultSopsFile = "${self}/home/${username}/secrets.yaml";
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
    ".ssh/id_ed25519.pub".source = "${self}/home/${username}/id_ed25519.pub";
  };

  systemd.user.services.ssh-to-age = {
    Unit = {
      Description = "Convert SSH keys to age keys";
    };

    Service = {
      Type = "oneshot";
      ExecStart = sshToAgeCommand;
    };

    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
