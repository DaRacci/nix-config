{
  self,
  outputs,
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib) mkIf mkEnableOption optional;
  inherit (builtins) mapAttrs readFile;
  inherit (config.networking) hostName;

  cfg = config.core.openssh;
  hosts = outputs.nixosConfigurations;

  mkPubKey =
    name:
    pkgs.writeTextFile {
      name = "${name}_ed25519.pub";
      text = readFile (lib.mine.files.findFile self "${name}/ssh_host_ed25519_key.pub");
    };

  hostSSHPubKey = mkPubKey config.host.name;
in
{
  options.core.openssh = {
    enable = mkEnableOption "OpenSSH server and client opinionated configuration" // {
      default = true;
    };
  };

  config = mkIf cfg.enable {
    users.users.root.openssh.authorizedKeys.keyFiles = [ hostSSHPubKey ];
    environment.etc."ssh/ssh_host_ed25519_key.pub".source = hostSSHPubKey;
    security.pam.sshAgentAuth.enable = true;

    services.openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = false;
        PermitRootLogin = "prohibit-password";
        GatewayPorts = "clientspecified";
      };

      hostKeys = [
        {
          inherit (config.sops.secrets.SSH_PRIVATE_KEY) path;
          type = "ed25519";
        }
      ];
    };

    programs.ssh = {
      hostKeyAlgorithms = [ "ssh-ed25519" ];
      pubkeyAcceptedKeyTypes = [ "ssh-ed25519" ];

      knownHosts = mapAttrs (name: _: {
        publicKeyFile = mkPubKey name;
        extraHostNames = optional (name == hostName) "localhost";
      }) hosts;
    };
  };
}
