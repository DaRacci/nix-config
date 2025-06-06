{
  self,
  outputs,
  config,
  pkgs,
  lib,
  ...
}:

let
  inherit (config.networking) hostName;
  hosts = outputs.nixosConfigurations;

  mkPubKey =
    hostName:
    pkgs.writeTextFile {
      name = "${hostName}_ed25519.pub";
      text = builtins.readFile (lib.mine.files.findFile self "${hostName}/ssh_host_ed25519_key.pub");
    };

  hostSSHPubKey = mkPubKey config.host.name;
in
{
  environment.etc = { };

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

    # Each hosts public key
    knownHosts = builtins.mapAttrs (name: _: {
      publicKeyFile = mkPubKey name;
      extraHostNames = lib.optional (name == hostName) "localhost"; # Alias for localhost if it's the same host
    }) hosts;
  };

  users.users.root = {
    openssh.authorizedKeys.keyFiles = [ hostSSHPubKey ];
  };

  # Passwordless sudo when SSH'ing with keys
  security.pam.sshAgentAuth.enable = true;

  environment.etc = {
    "ssh/ssh_host_ed25519_key.pub".source = hostSSHPubKey;
  };
}
