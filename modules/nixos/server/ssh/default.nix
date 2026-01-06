{
  config,
  lib,
  ...
}:
let
  cfg = config.server.sshShell;
in
{
  options.server.sshShell = {
    enable =
      lib.mkEnableOption "Auto-enter a session-only devShell for root on interactive SSH logins."
      // {
        default = true;
      };

    shellFile = lib.mkOption {
      type = lib.types.path;
      default = ./shell.nix;
      description = ''
        Path to a single-file that defines a session-only environment.
        This file is evaluated by nix-shell and should import <nixpkgs> to use the system registry.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.openssh.settings = {
      AcceptEnv = [ "NIX_SKIP_SHELL" ];
    };

    environment.etc."bashrc".text = ''
      # Conditions:
      # - EUID == 0 (root)
      # - SSH_CONNECTION is set (SSH session)
      # - stdin is a tty (interactive)
      # - Not already inside the devShell (guard by SSH_NIX_SHELL)
      # - NIX_SKIP_SHELL is not set (allows opt-out)
      if [ "''${EUID:-}" = "0" ] \
         && [ -n "''${SSH_CONNECTION:-}" ] \
         && [ -t 0 ] \
         && [ -z "''${SSH_NIX_SHELL:-}" ] \
         && [ -z "''${NIX_SKIP_SHELL:-}" ]; then
        export SSH_NIX_SHELL=1

        if nix-shell "${cfg.shellFile}"; then
          exit $?
        else
          echo "SSH devShell failed to start; continuing with default shell." >&2
          unset SSH_NIX_SHELL
        fi
      fi
    '';
  };
}
