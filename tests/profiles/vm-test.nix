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
    readOnly = true;
  };

  # Stub options for services that are force-disabled below but whose module
  # may not be imported in scenario tests.
  options.services.mcpo = lib.mkOption {
    type = lib.types.submodule {
      options.enable = lib.mkEnableOption "mcpo service";
    };
    default = { };
  };

  # Declare proxmoxLXC options so mkForce works on all hosts
  # (option only exists on hosts importing generators.nix).
  options.services.seaweedfs = lib.mkOption {
    type = lib.types.attrsOf lib.types.unspecified;
    default = { };
  };

  options.proxmoxLXC = lib.mkOption {
    type = lib.types.attrsOf lib.types.unspecified;
    default = { };
    internal = true;
  };

  config = {
    sops.secrets.SSH_PRIVATE_KEY = { };

    # --- ENABLED: required by baseline assertions ---
    services.openssh.enable = true;

    # --- DISABLED: needs real external credentials ---
    services.tailscale.enable = lib.mkForce false; # Needs real auth key / OAuth client.
    services.mcpo.enable = lib.mkForce false; # Needs GitHub, AniList tokens.

    # --- DISABLED: needs GPU ---
    services.ollama.enable = lib.mkForce false; # No GPU in QEMU.

    # --- OVERRIDDEN: conflicts with QEMU test driver ---
    proxmoxLXC.manageNetwork = lib.mkForce false;
    proxmoxLXC.manageHostName = lib.mkForce false;

    # --- POSTGRESQL: disable JIT (needs LLVM at runtime), add trust auth ---
    services.postgresql = {
      enableJIT = lib.mkForce false;
      authentication = lib.mkOverride 1500 ''
        local all all trust
        host all all 127.0.0.1/32 trust
        host all all ::1/128 trust
      '';
    };

    systemd.services.caddy.after = lib.mkForce [ "network.target" ];
    systemd.services.caddy.wants = lib.mkForce [ ];

    # --- PGADMIN: skip initial password file (use default login) ---
    services.pgadmin.initialPasswordFile = lib.mkForce null;

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
