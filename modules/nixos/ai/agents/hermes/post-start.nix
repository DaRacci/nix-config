{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    concatStringsSep
    imap0
    mkIf
    mkOption
    optionalString
    types
    ;
  inherit (types)
    bool
    either
    listOf
    str
    submodule
    ;
  inherit (builtins)
    filter
    isString
    ;

  cfg = config.services.ai-agent;
in
{
  options.services.ai-agent.containerPostStart = mkOption {
    type = listOf (
      either str (submodule {
        options = {
          command = mkOption {
            type = str;
            description = "Shell command to run.";
          };

          host = mkOption {
            type = bool;
            default = false;
            description = ''
              Run on the host instead of inside the container.
            '';
          };
        };
      })
    );
    default = [ ];
    description = ''
      Shell commands to run inside the Hermes container after startup.

      A plain string runs inside the container as root via docker exec.
      An attrset `{ command = "..."; host = true; }` runs on the host.

      Commands to run after the AI agent container starts.
      Container commands get automatic retry to wait for Docker + container readiness.
    '';
  };

  config = mkIf (cfg.enable && cfg.containerPostStart != [ ]) {
    systemd.services.hermes-agent.postStart =
      let
        normalize =
          cmd:
          if isString cmd then
            {
              inherit cmd;
              host = false;
            }
          else
            {
              cmd = cmd.command;
              host = cmd.host;
            };
        cmds = map normalize cfg.containerPostStart;
        containerCmds = filter (c: !c.host) cmds;
        hostCmds = filter (c: c.host) cmds;
        containerScript = optionalString (containerCmds != [ ]) (
          pkgs.writeShellScript "hermes-container-poststart" (
            ''
              echo "[hermes-agent] container postStart starting..." >&2
            ''
            + concatStringsSep "\n\n" (
              imap0 (n: c: ''
                echo "[hermes-agent] container postStart #${toString (n + 1)}..." >&2
                ${lib.removeSuffix "\n" c.cmd} || echo "[hermes-agent] container postStart #${toString (n + 1)} FAILED (exit $?)" >&2
              '') containerCmds
            )
          )
        );
      in
      ''
        # Wait for Docker daemon + container to be ready
        for i in $(seq 1 10); do
          if ${pkgs.docker}/bin/docker exec -u root hermes-agent true 2>/dev/null; then
            break
          fi
          sleep 2
        done
      ''
      + optionalString (containerCmds != [ ]) ''
        ${pkgs.docker}/bin/docker exec -u root hermes-agent ${containerScript} 2>&1 || echo "[hermes-agent] container postStart FAILED (exit $?)" >&2
      ''
      + optionalString (hostCmds != [ ]) ""
      + concatStringsSep "\n" (
        imap0 (n: c: ''
          echo "[hermes-agent] host postStart #${toString (n + 1)}..." >&2
          (${c.cmd}) 2>&1 || echo "[hermes-agent] host postStart #${toString (n + 1)} FAILED (exit $?)" >&2
        '') hostCmds
      );
  };
}
