# VM Test Profile
# Centralized policy for QEMU VM tests. Disables services, overrides options,
# generates deterministic secrets. Injected into every test node.
{
  config,
  pkgs,
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
          owner = lib.mkOption {
            type = lib.types.str;
            default = "root";
          };
          group = lib.mkOption {
            type = lib.types.str;
            default = "root";
          };
          mode = lib.mkOption {
            type = lib.types.str;
            default = "0400";
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

  # Stubs for services whose option declarations come from external flake inputs
  # (importExternals = false in test context).
  options.services.seaweedfs = lib.mkOption {
    type = lib.types.submodule {
      freeformType = lib.types.attrsOf lib.types.unspecified;
      options = {
        enable = lib.mkEnableOption "seaweedfs";
        package = lib.mkOption { type = lib.types.package; default = pkgs.hello; };
      };
    };
    default = { };
  };

  options.proxmoxLXC = lib.mkOption {
    type = lib.types.attrsOf lib.types.unspecified;
    default = { };
    internal = true;
  };

  config = {
    sops.secrets.SSH_PRIVATE_KEY = { path = lib.mkForce "/run/secrets/SSH_PRIVATE_KEY"; };

    # --- ENABLED: required by baseline assertions ---
    # --- BOOT: mkForce disable systemd-boot (VM uses init-script builder) ---
    boot.loader.systemd-boot.enable = lib.mkForce false;

    # Ensure initrd is built for qemu-vm
    boot.initrd.enable = true;

    services.openssh = {
      enable = true;
      # Override production hostKeys — production maps SSH_PRIVATE_KEY to
      # /etc/ssh/ssh_host_ed25519_key. Writing deterministic content there
      # produces an invalid key. Let sshd auto-generate host keys.
      hostKeys = lib.mkForce [
        { type = "ed25519"; path = "/etc/ssh/ssh_host_ed25519_key"; }
        { type = "rsa"; bits = 4096; path = "/etc/ssh/ssh_host_rsa_key"; }
      ];
      settings = {
        PermitRootLogin = lib.mkForce "yes";
        PasswordAuthentication = lib.mkForce true;
      };
    };

    # --- DISABLED: needs real external credentials ---
    services.tailscale.enable = lib.mkForce false; # Needs real auth key / OAuth client.
    services.mcpo.enable = lib.mkForce false; # Needs GitHub, AniList tokens.

    # --- DISABLED: needs GPU ---
    services.ollama.enable = lib.mkForce false; # No GPU in QEMU.

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
    services.pgadmin.initialPasswordFile = lib.mkForce "/dev/null";

    # --- OVERRIDDEN: conflicts with QEMU test driver ---
    # proxmoxLXC is declared by hosts/server/shared (not imported),
    # services.seaweedfs and services.mcpo are declared by modules/nixos.
    # QEMU test driver may override networking/hostname at runtime.

    # --- DETERMINISTIC SECRETS ---
    # Writes each declared secret at its path with content derived from
    # the name. Same name → same content across all test hosts.
    systemd.tmpfiles.rules = lib.mapAttrsToList (
      name: secret:
      let
        content = "test-${hashString "sha256" name}";
      in
      "f+ ${secret.path} ${secret.mode} ${secret.owner} ${secret.group} - ${content}"
    ) (lib.filterAttrs (name: _: name != "SSH_PRIVATE_KEY") config.sops.secrets);
  };

}
