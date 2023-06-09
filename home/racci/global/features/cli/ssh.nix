{ outputs, lib, config, ... }:
let
  hostnames = builtins.attrNames outputs.nixosConfigurations;
in {
  programs.ssh = {
    enable = true;

    matchBlocks = {
      hosts = {
        host = builtins.concatStringsSep " " hostnames;
        forwardAgent = true;
        extraOptions = {
          IdentityAgent = "~/.1password/agent.sock";
        };
      };

      other = {
        host = "*";
        extraOptions = {
          IdentityAgent = "~/.1password/agent.sock";
        };
      };
    };
  };

  home.persistence."/persist/home/racci".directories = [ ".ssh" ];
}