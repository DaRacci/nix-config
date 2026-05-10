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

        profile_root=/nix/var/nix/gcroots/per-user/root/ssh-shell
        profile_link=/nix/var/nix/gcroots/per-user/root/ssh-shell-result

        if shell_drv=$(nix-instantiate "${cfg.shellFile}") && \
          shell_path=$(nix-store --add-root "$profile_link" --indirect --realise "$shell_drv" 2>/dev/null | tail -n1); then
          ln -sfn "$profile_link" "$profile_root"
          if [ -x "$shell_path/bin/fish" ]; then
            exec "$shell_path/bin/fish" -C "source $shell_path"
          fi
        fi

        echo "SSH devShell failed to start; continuing with default shell." >&2
        unset SSH_NIX_SHELL
        return 0
      fi
    '';
  };
}
