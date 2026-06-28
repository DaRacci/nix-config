# VM Test Profile
# Centralized policy for QEMU VM tests. Disables services, overrides options,
# generates deterministic secrets. Injected into every test node.
{
  config,
  lib,
  ...
}:
let
  inherit (builtins) hashString;
in
{
  # Declare sops.secrets / sops.templates options so host configs that
  # reference them evaluate. No sops-nix import - avoids convertHash
  # (Lix 2.94 missing builtins.convertHash) and doesn't need real keys.
  options.sops.secrets = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule (
        { name, ... }:
        {
          options = {
            path = lib.mkOption {
              type = lib.types.str;
              default = "/run/secrets/${name}";
            };
            mode = lib.mkOption {
              type = lib.types.str;
              default = "0400";
            };
            owner = lib.mkOption {
              type = lib.types.str;
              default = "root";
            };
            group = lib.mkOption {
              type = lib.types.str;
              default = "root";
            };
            sopsFile = lib.mkOption {
              type = lib.types.nullOr lib.types.path;
              default = null;
            };
            format = lib.mkOption {
              type = lib.types.enum [
                "binary"
                "text"
              ];
              default = "text";
            };
            key = lib.mkOption {
              type = lib.types.str;
              default = "";
            };
            restartUnits = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
            };
            neededForUsers = lib.mkOption {
              type = lib.types.bool;
              default = false;
            };
          };
        }
      )
    );
    default = { };
  };

  options.sops.templates = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule (_: {
        options = {
          path = lib.mkOption {
            type = lib.types.str;
            default = "/run/templates/%{name}";
          };
          content = lib.mkOption {
            type = lib.types.str;
            default = "";
          };
          restartUnits = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
          };
        };
      })
    );
    default = { };
  };

  options.sops.placeholder = lib.mkOption {
    type = lib.types.attrsOf lib.types.str;
    default = { };
    readonly = true;
  };

  config = {
    # --- DISABLED: needs real external credentials ---
    services.tailscale.enable = lib.mkForce false; # Needs real auth key / OAuth client.
    services.mcpo.enable = lib.mkForce false; # Needs GitHub, AniList tokens.

    # --- DISABLED: needs GPU ---
    services.ollama.enable = lib.mkForce false; # No GPU in QEMU.

    # --- OVERRIDDEN: conflicts with QEMU test driver ---
    proxmoxLXC.manageNetwork = lib.mkForce false;
    proxmoxLXC.manageHostName = lib.mkForce false;

    # --- DETERMINISTIC SECRETS ---
    # Writes each declared secret at its path with content derived from
    # the name. Same name → same content across all test hosts.
    systemd.tmpfiles.rules = lib.mapAttrsToList (
      name: secret:
      let
        content = "test-${hashString "sha256" name}";
      in
      "f ${secret.path} ${secret.mode} ${secret.owner} ${secret.group} - ${content}"
    ) config.sops.secrets;
  };

}
