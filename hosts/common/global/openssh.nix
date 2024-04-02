{ outputs, config, pkgs, lib, ... }:

let
  inherit (config.networking) hostName;
  hosts = outputs.nixosConfigurations;

  mkPubKey = hostName: pkgs.writeTextFile {
    name = "${hostName}_ed25519.pub";
    text = builtins.readFile (lib.mine.files.findFile "${hostName}/ssh_host_ed25519_key.pub");
  };

  hostSSHPubKey = mkPubKey config.host.name;
  hostSSHPrivKey = pkgs.writeTextFile {
    name = "${config.host.name}_ed25519";
    text = builtins.readFile config.sops.secrets.SSH_PRIVATE_KEY.path;
  };
in
{
  environment.etc = { };

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
      GatewayPorts = "clientspecified";
    };

    hostKeys = [{
      path = hostSSHPubKey;
      type = "ed25519";
    }];
  };

  programs.ssh = {
    # Each hosts public key
    knownHosts = builtins.mapAttrs
      (name: _: {
        publicKeyFile = mkPubKey name;
        extraHostNames = lib.optional (name == hostName) "localhost"; # Alias for localhost if it's the same host
      })
      hosts;
  };

  users.users.root = {
    openssh.authorizedKeys.keys = [ (builtins.readFile hostSSHPubKey) ];
  };

  # Passwordless sudo when SSH'ing with keys
  security.pam.enableSSHAgentAuth = true;

  environment.etc = {
    "ssh/ssh_host_ed25519_key".source = hostSSHPrivKey;
    "ssh/ssh_host_ed25519_key.pub".source = hostSSHPubKey;
  };
}
