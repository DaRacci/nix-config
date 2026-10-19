{
  self,
  config,
  lib,
  ...
}:
let
  inherit (lib) mkOption types literalExpression;
  inherit (types) path;

  cfg = config.user;

  keyPath = "${self}/home/${config.home.username}/id_ed25519.pub";
in
{
  options.core.profile.identity = {
    publicKey = mkOption {
      type = path;
      default = keyPath;
      defaultText = literalExpression ''builtins.readFile "''${self}/home/''${config.home.username}/id_ed25519.pub"'';
      description = ''
        The path to the users public key file.

        This is used for a wide variety of purposes, including but not limited to:
        - Git Signing
        - SSH Authentication
        - SOPS Secret Decryption
      '';
    };
  };

  assertions = [
    {
      assertion = builtins.pathExists cfg.publicKey;
      message = ''
        The public key file ${cfg.publicKey} does not exist.

        If you are receiving this error, you may need to set `core.profile.identity.publicKey` to a valid path of your public key.
        This is typically automatically set to the public key in your flake at `home/<username>/id_ed25519.pub`.
      '';
    }
  ];

  config = {
    home.file.".ssh/id_ed25519.pub" = {
      source = cfg.publicKey;
    };


  };
}
