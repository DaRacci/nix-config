{
  outputs,
  config,
  lib,
  ...
}:
let
  cfg = config.user;
  hostnames = builtins.attrNames outputs.nixosConfigurations;
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

    programs.ssh = {
      enable = true;

      matchBlocks = {
        hosts = {
          host = builtins.concatStringsSep " " hostnames;
          forwardAgent = true;
          identitiesOnly = true;
          extraOptions = {
            IdentityAgent = cfg.sshSocket;
          };
        };

        other = {
          host = "*";
          extraOptions = {
            IdentityAgent = cfg.sshSocket;
          };
        };
      };
    };

    user.persistence.files = [ ".ssh/known_hosts" ];
  };
}
