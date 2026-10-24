{
  inputs,
  config,
  lib,
  pkgs,
  importExternals ? true,
  ...
}:
let
  inherit (lib)
    literalExpression
    mkEnableOption
    mkIf
    mkOption
    optional
    types
    ;
  inherit (types)
    int
    listOf
    path
    str
    ;

  cfg = config.server.sshGuard;
  ruleSet = import ./rules.nix {
    inherit config lib pkgs;
    inherit (cfg) endpoints tailRoots lsRoots catRoots;
  };
in
{
  imports = optional importExternals inputs.ssh-guard.nixosModules.default;

  options.server.sshGuard = {
    enable =
      mkEnableOption "the read-only ssh-guard observer account"
      // {
        default = config.host.device.role == "server";
        defaultText = literalExpression ''config.host.device.role == "server"'';
      };

    user = mkOption {
      type = str;
      default = "sysops";
      description = "Account forced through the guard.";
    };

    authorizedKeyFiles = mkOption {
      type = listOf path;
      default = [ ./authorized-key.pub ];
      description = "Public keys allowed to log in as {option}`server.sshGuard.user`.";
    };

    extraGroups = mkOption {
      type = listOf str;
      default = [ ];
      description = "Extra groups for the account; read-only ones only.";
      example = [ "caddy" ];
    };

    tailRoots = mkOption {
      type = listOf str;
      default = [ ];
      description = "Path prefixes the `tail` command may read. Empty disables it.";
      example = [ "/var/log/caddy" ];
    };

    lsRoots = mkOption {
      type = listOf str;
      default = [ ];
      description = "Extra path prefixes the `ls` command may list, on top of the defaults.";
    };

    catRoots = mkOption {
      type = listOf str;
      default = [ ];
      description = "Extra path prefixes `cat` may read, on top of the defaults.";
      example = [ "/etc/caddy" ];
    };

    endpoints = mkOption {
      type = listOf str;
      default = [ ];
      description = "Exact URLs the `curl` command may request. Empty disables it.";
      example = [ "http://127.0.0.1:9090/-/healthy" ];
    };

    extraRules = mkOption {
      type = listOf types.attrs;
      default = [ ];
      description = "Host-specific rules appended to the observer profile.";
    };

    auditLog = mkOption {
      type = str;
      default = "/var/log/ssh-guard-audit.log";
      description = "File attempts are appended to.";
    };

    maxReadBytes = mkOption {
      type = int;
      default = 1048576;
      description = "Maximum bytes a `cat` action will emit.";
    };

    maxTailLines = mkOption {
      type = int;
      default = 2000;
      description = "Hard cap on `log` line counts.";
    };
  };

  config = mkIf cfg.enable {
    # Extended by host definitions; mkForce replaces them.
    server.sshGuard.lsRoots = [ "/var/lib" ];
    server.sshGuard.catRoots = [ "/nix/store" ];

    assertions = [
      {
        assertion = cfg.authorizedKeyFiles != [ ];
        message = "`server.sshGuard.authorizedKeyFiles` is empty, leaving the account unusable.";
      }
    ];

    users.groups.${cfg.user} = { };

    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.user;
      home = "/run/${cfg.user}";
      createHome = true;
      # ssh-guard runs the forced command through the login shell.
      shell = pkgs.bash;
      extraGroups = [ "systemd-journal" ] ++ cfg.extraGroups;
      openssh.authorizedKeys.keyFiles = cfg.authorizedKeyFiles;
    };

    services.ssh-guard = {
      enable = true;

      settings = {
        global = {
          audit_log = cfg.auditLog;
          audit_format = "json";
          log_tag = "ssh-guard";
          max_read_bytes = cfg.maxReadBytes;
          max_tail_lines = cfg.maxTailLines;
          default_tail_lines = 200;
        };

        inherit (ruleSet) root_sets flag_groups contracts;
      };

      profiles.${cfg.user} = {
        users = [ cfg.user ];
        settings = {
          rules = ruleSet.rules ++ cfg.extraRules;
        };
      };
    };
  };
}
