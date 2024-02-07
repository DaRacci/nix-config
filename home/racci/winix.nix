{ pkgs, lib, ... }: rec {
  imports = [
    ./features/cli
  ];

  home.sessionVariables = {
    LD_LIBRARY_PATH = "/usr/lib/wsl/lib";
    SSH_AUTH_SOCK = "/home/racci/.ssh/wsl-ssh-agent.sock";
  };

  programs.bash = {
    enable = true;

    bashrcExtra = ''
      /home/racci/.local/bin/wsl-ssh-agent-relay start
    '';

    initExtra = ''
      ${pkgs.nushell}/bin/nu -il
    '';
  };

  purpose.development = {
    enable = true;
    rust.enable = true;
  };

  users.users.racci.home.shell = pkgs.nushell;

  programs.git = {
    signing.key = lib.mkForce "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDqwbL8BvpSKb1AYbHOIv3sM+QDNLZfAaSJnBZcOl71C";
    extraConfig.gpg.ssh.program = lib.mkForce "ssh-keygen";
    extraConfig.core.sshCommand = lib.mkForce "ssh-keygen";
  };

  home.file.".local/bin/wsl-ssh-agent-relay" = {
    executable = true;

    text =
      let
        RELAY_BIN = "/home/racci/.local/bin/npiperelay.exe";
        SOCAT_BIN = "${pkgs.socat}/bin/socat";

        PIDFILE = builtins.replaceStrings [ ".sock" ] [ ".pid" ] home.sessionVariables.SSH_AUTH_SOCK;
        WSL_AGENT_SSH_SOCK = home.sessionVariables.SSH_AUTH_SOCK;
      in
      ''
        #!${pkgs.stdenv.shell}

        exec 2> >(tee -a -i "$HOME/error.log")

        log() {
            echo >&2 "$@"
        }

        is_pid_running() {
            if [[ -z "$1" ]]; then
                return 1
            fi
            ps -p "$1" >/dev/null
            return $?
        }

        _cleanup() {
            log "Cleaning up relay to ${WSL_AGENT_SSH_SOCK}..."
            if is_pid_running "''${SOCAT_WSL_AGENT_SSH_PID}"; then
                kill -SIGTERM "''${SOCAT_WSL_AGENT_SSH_PID}" || log "Failed."
            fi
        }

        die() {
            if [[ -n "$1" ]]; then
                log "$1"
            fi
            log "Exiting."
            exit 1
        }

        usage() {
            log "Usage: wsl-ssh-agent-relay [OPTIONS] COMMAND"
            log ""
            log "  SUMMARY: Relay Windows openssh named pipe to local SSH socket in order to integrate WSL2 and host."
            log "           To debug use foreground command"
            log ""
            log "  OPTIONS:"
            log "    -h|--help          this page"
            log ""
            log "    -v|--verbose       verbose mode"
            log ""
            log "    -s|--skip-test     skip ssh-agent communication test"
            log ""
            log "  COMMAND: start, stop, foreground"
        }

        fg_opts() {
            FG_OPTS=()
            # Generate opts for passing it to foreground version
            if [[ -n "$VERBOSE" ]]; then
                FG_OPTS+=("-v")
            fi
            if [[ -n "$NO_COM_TEST" ]]; then
                FG_OPTS+=("-c")
            fi
        }

        main() {

            POSITIONAL=()
            VERBOSE=""
            SKIP_SSH_TEST=""
            while (($# > 0)); do
                case "$1" in
                -v | --verbose)
                    VERBOSE="ENABLED"
                    shift # shift once since flags have no values
                    ;;

                -s | --skip-test)
                    SKIP_SSH_TEST="TRUE"
                    shift
                    ;;

                -h | --help)
                    usage
                    exit 0
                    ;;

                *) # unknown flag/switch
                    POSITIONAL+=("$1")
                    shift
                    if [[ "''${#POSITIONAL[@]}" -gt 1 ]]; then
                        usage
                        die
                    fi
                    ;;
                esac
            done

            set -- "''${POSITIONAL[@]}" # restore positional params

            if [[ -z "$VERBOSE" ]]; then
                QUIET="QUIET"
            fi

            case "''${POSITIONAL[0]}" in
            start)
                fg_opts
                ${pkgs.busybox}/bin/start-stop-daemon --start --oknodo --pidfile "${PIDFILE}" --name wsl-ssh-agent-r --make-pidfile --background --startas "$0" ''${VERBOSE:+--verbose} ''${QUIET:+--quiet} -- foreground "''${FG_OPTS[@]}"
                ;;

            stop)
                ${pkgs.busybox}/bin/start-stop-daemon --pidfile "${PIDFILE}" --stop --remove-pidfile ''${VERBOSE:+--verbose} ''${QUIET:+--quiet}
                ;;

            status)
                ${pkgs.busybox}/bin/start-stop-daemon --pidfile "${PIDFILE}" --status ''${VERBOSE:+--verbose} ''${QUIET:+--quiet}
                local result=$?
                case $result in
                0) log "$0 is running" ;;
                1 | 3) log "$0 is not running" ;;
                4) log "$0 unable to determine status" ;;
                esac
                return $result
                ;;

            foreground)
                relay
                ;;

            *)
                usage
                die
                ;;
            esac
        }

        relay() {

            trap _cleanup EXIT

            [[ -f "${RELAY_BIN}" ]] || die "Unable to access ${RELAY_BIN}"

            if pgrep -fx "^ssh-agent\s.+" >/dev/null; then
                log "Killing previously started local ssh-agent..."
                SSH_AGENT_PID="$(pidof ssh-agent)" ssh-agent -k >/dev/null 2>&1
            fi

            if [ -e "${WSL_AGENT_SSH_SOCK}" ]; then
                log "WSL has been shutdown ungracefully, leaving garbage behind"
                rm "${WSL_AGENT_SSH_SOCK}"
            fi

            ${SOCAT_BIN} UNIX-LISTEN:"\"${WSL_AGENT_SSH_SOCK}\"",fork EXEC:"\"\'${RELAY_BIN}\' -ei -s \'//./pipe/openssh-ssh-agent\'\"",nofork 1>/dev/null 2>&1 &
            SOCAT_WSL_AGENT_SSH_PID="$!"
            if ! is_pid_running "''${SOCAT_WSL_AGENT_SSH_PID}"; then
                log "Relay for ''${SOCAT_WSL_AGENT_SSH_PID} failed"
                return 1
            fi
            log "Relay is running with PID: ''${SOCAT_WSL_AGENT_SSH_PID}"

            if [[ -z "$SKIP_SSH_TEST" ]]; then
                local res
                log -n "Polling remote ssh-agent..."
                SSH_AUTH_SOCK="${WSL_AGENT_SSH_SOCK}" ssh-add -L >/dev/null 2>&1
                res=$?
                [[ "''${res}" -ge 2 ]] && die "[''${res}] Failure communicating with ssh-agent"
                log "OK"
            fi

            # Everything necessary checks, we are ready for actions
            log "Entering wait..."
            wait ''${SOCAT_WSL_AGENT_SSH_PID}
        }

        main "$@"
      '';
  };
}
