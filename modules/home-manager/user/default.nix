{
  self,
  outputs,
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.user;
  hostnames = builtins.attrNames outputs.nixosConfigurations;

  userPublicKey = builtins.readFile "${self}/home/${config.home.username}/id_ed25519.pub";
in
{
  imports = [
    ./autorun.nix
    ./persistence.nix
  ];

  options.user = {
    sshSocket = lib.mkOption {
      type = lib.types.str;
      default = "/home/${config.home.username}/.1password/agent.sock";
    };
  };

  config = {
    home.sessionVariables = {
      SSH_AUTH_SOCK = cfg.sshSocket;
    };

    programs = {
      ssh = {
        enable = true;
        enableDefaultConfig = false;

        matchBlocks = {
          hosts = {
            host = builtins.concatStringsSep " " hostnames;
            forwardAgent = true;
            identitiesOnly = true;
            setEnv = {
              TERM = "xterm-256color";
            };
          };

          "*" = {
            host = "*";
            identityAgent = cfg.sshSocket;
          };
        };
      };

      git.settings = {
        gpg.ssh.allowedSignersFile =
          (pkgs.writeTextFile {
            name = "allowed-signers";
            text = pkgs.lib.concatStringsSep "\n" [
              "${config.programs.git.settings.user.email} ${userPublicKey}"
            ];
          }).outPath;

        signing.key = userPublicKey;
      };
    };

    user.persistence.files = [ ".ssh/known_hosts" ];
  };
}
