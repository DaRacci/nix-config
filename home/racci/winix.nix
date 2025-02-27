{ pkgs, lib, ... }:
let
  SSH_AUTH_SOCK = "/home/racci/.ssh/wsl-ssh-agent.sock";
  RELAY_SCRIPT = pkgs.writeShellScriptBin "ssh-relay" ''
    function start() {
      if [[ -S ${SSH_AUTH_SOCK} ]]; then
        echo "removing previous socket..."
        rm ${SSH_AUTH_SOCK}
      fi
      echo "Starting SSH-Agent relay..."
      (setsid ${lib.getExe pkgs.socat} UNIX-LISTEN:${SSH_AUTH_SOCK},fork EXEC:"/home/racci/.local/bin/npiperelay.exe -ei -s //./pipe/openssh-ssh-agent",nofork &) >/dev/null 2>&1
    }

    function stop() {
      echo "Stopping SSH-Agent relay..."
      if [[ -S ${SSH_AUTH_SOCK} ]]; then
        rm ${SSH_AUTH_SOCK}
      fi
    }

    function status() {
      if [[ -S ${SSH_AUTH_SOCK} ]]; then
        if pgrep -fx "^${lib.getExe pkgs.socat}\s.+" >/dev/null; then
            local res
            echo "Polling remote ssh-agent..."
            SSH_AUTH_SOCK="${SSH_AUTH_SOCK}" ssh-add -L >/dev/null 2>&1
            res=$?
            if [[ "''${res}" -ge 2 ]]; then
              "[''${res}] Failure communicating with ssh-agent"
              exit 1
            fi
          if SSH_AUTH_SOCK=${SSH_AUTH_SOCK} ssh-add -L >/dev/null 2>&1; then
            echo "SSH-Agent relay is running and working."
          else
            echo "SSH-Agent relay is running but not working."
          fi
        else
          echo "SSH-Agent relay is not running."
        fi
      else
        echo "SSH-Agent relay is not running."
      fi
    }

    case "$1" in
      start)
        start
        ;;
      stop)
        stop
        ;;
      status)
        status
        ;;
      *)
        echo "Usage: ssh-relay [start|stop|status]"
        ;;
    esac
  '';
in
{
  imports = [
    ./features/cli.
    ./features/desktop/zed.nix
  ];

  user.sshSocket = SSH_AUTH_SOCK;

  home = {
    sessionVariables = {
      LD_LIBRARY_PATH = "/usr/lib/wsl/lib";
    };

    file.".local/bin/ssh-relay" = {
      executable = true;
      source = lib.getExe RELAY_SCRIPT;
    };
  };

  purpose.development = {
    enable = true;
    rust.enable = true;
    vscode.enable = false;
  };

  programs.git = {
    signing.key = lib.mkForce "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKR0l+66/jg7SdHgam44I26+yJaEIa7cEO2QBtshzDxb";
    extraConfig.gpg.ssh.program = lib.mkForce "ssh-keygen";
    extraConfig.core.sshCommand = lib.mkForce "ssh-keygen";
  };

  systemd.user.services."wsl-ssh-agent-relay" = {
    Unit = {
      Description = "Relay Windows openssh named pipe to local SSH socket in order to integrate WSL2 and host.";
    };

    Service = {
      Type = "oneshot";
      RemainAfterExit = true;
      PassEnvironment = [ "SSH_AUTH_SOCK" ];
      ExecStart = "${lib.getExe RELAY_SCRIPT} start";
      ExecStop = "${lib.getExe RELAY_SCRIPT} stop";
      ExecStatus = "${lib.getExe RELAY_SCRIPT} status";
    };

    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
