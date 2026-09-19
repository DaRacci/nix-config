{
  self,
  outputs,
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib)
    mkIf
    mkEnableOption
    mkOption
    optional
    ;
  inherit (lib.types) str;
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

    hostPrivateKeyPath = mkOption {
      type = str;
      default = "/var/lib/provisioning/ssh/ssh_host_ed25519_key";
      description = ''
        Canonical path of the provisioned ed25519 host private key used by
        OpenSSH, SOPS age decryption, and server-to-server SSH.
      '';
    };
  };

  config = mkIf cfg.enable {
    host.persistence.files = [ cfg.hostPrivateKeyPath ];
    users.users.root.openssh.authorizedKeys.keyFiles = [ hostSSHPubKey ];
    environment.etc."ssh/ssh_host_ed25519_key.pub".source = hostSSHPubKey;
    security.pam.sshAgentAuth.enable = true;

    services.openssh = {
      enable = true;
      startWhenNeeded = false;
      settings = {
        PasswordAuthentication = false;
        PermitRootLogin = "prohibit-password";
        GatewayPorts = "clientspecified";
      };

      hostKeys = [
        {
          path = cfg.hostPrivateKeyPath;
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
