{
  outputs,
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib) mkOption types literalExpression;
  inherit (types) str;

  cfg = config.user;
  hostnames = builtins.attrNames outputs.nixosConfigurations;
in
{
  imports = [
    ./autorun.nix
    ./backup.nix
    ./persistence.nix
  ];

  options.user = {
    sshSocket = mkOption {
      type = str;
      default = "/home/${config.home.username}/.1password/agent.sock";
      defaultText = literalExpression ''"/home/${config.home.username}/.1password/agent.sock"'';
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

        settings = {
          "${builtins.concatStringsSep " " hostnames}" = {
            ForwardAgent = true;
            IdentitiesOnly = true;
            SetEnv = {
              TERM = "xterm-256color";
            };
          };

          "*" = {
            IdentityAgent = cfg.sshSocket;
          };
        };
      };
    };

    user.persistence.files = [ ".ssh/known_hosts" ];
  };
}
