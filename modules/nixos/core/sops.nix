{
  inputs,
  config,
  lib,
  hostDirectory,
  importExternals ? true,
  ...
}:
let
  inherit (lib)
    mkIf
    mkOption
    mkEnableOption
    types
    optional
    literalExpression
    ;
  inherit (types) path;
  cfg = config.core.sops;

  isEd25519 = k: k.type == "ed25519";
  getKeyPath = k: k.path;
  keys = builtins.filter isEd25519 config.services.openssh.hostKeys;
in
{
  imports = optional importExternals inputs.sops-nix.nixosModules.sops;

  options.core.sops = {
    enable = mkEnableOption "SOPS auto configuration" // {
      default = config.core.enable;
      defaultText = literalExpression "config.core.enable";
    };

    hostSecretsFile = mkOption {
      type = path;
      default = "${hostDirectory}/secrets.yaml";
      description = "Where the SOPS secret file of this host is located in the flake.";
    };
  };

  config = mkIf cfg.enable {
    sops = {
      defaultSopsFile = cfg.hostSecretsFile;
      age.sshKeyPaths = [
        "${config.host.persistence.root}/etc/ssh/ssh_host_ed25519_key"
      ]
      ++ (map getKeyPath keys);

      secrets = {
        SSH_PRIVATE_KEY = {
          path = "/etc/ssh/ssh_host_ed25519_key";
          restartUnits = [ "sshd.service" ];
        };
      };
    };
  };
}
