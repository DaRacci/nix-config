{ pkgs, lib, ... }:
let
  inherit (lib) getExe;

  SSH_AUTH_SOCK = "/home/racci/.ssh/wsl-ssh-agent.sock";
  sshRelay = getExe pkgs.ssh-relay;
in
{
  imports = [
    ./features/cli
    ./features/desktop/common/zed.nix
  ];

  user.sshSocket = SSH_AUTH_SOCK;

  home = {
    file.".local/bin/ssh-relay" = {
      executable = true;
      source = sshRelay;
    };
  };

  purpose = {
    enable = true;
    development = {
      enable = true;
      rust.enable = true;
      editors = {
        vscode.enable = false;
        helix.enable = true;
      };
    };
  };

  programs = {
    zellij.settings.mouse_mode = false;
    git = {
      signing.key = lib.mkForce "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKR0l+66/jg7SdHgam44I26+yJaEIa7cEO2QBtshzDxb";
      extraConfig.gpg.ssh.program = lib.mkForce "ssh-keygen";
      extraConfig.core.sshCommand = lib.mkForce "ssh-keygen";
    };
  };

  systemd.user.services."wsl-ssh-agent-relay" = {
    Unit = {
      Description = "Relay Windows openssh named pipe to local SSH socket in order to integrate WSL2 and host.";
    };

    Service = {
      Type = "oneshot";
      RemainAfterExit = true;
      Environment = [
        "SSH_RELAY_SOCKET_PATH=${SSH_AUTH_SOCK}"
        "SSH_RELAY_TARGET_COMMAND=/home/racci/.local/bin/npiperelay.exe -ei -s //./pipe/openssh-ssh-agent"
      ];
      ExecStart = "${sshRelay} start";
      ExecStop = "${sshRelay} stop";
      ExecStatus = "${sshRelay} status";
    };

    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
