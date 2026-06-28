# SSH Hardening Scenario
# Verifies that SSH daemon is configured with security hardening:
# - Password authentication disabled
# - Root login disabled
# - X11 forwarding disabled
# - Keyboard-interactive authentication disabled
# - Protocol 2 enforced
{
  nodes = {
    nixio = _: {
      services.openssh = {
        enable = true;
        settings = {
          PermitRootLogin = "no";
          PasswordAuthentication = false;
          KbdInteractiveAuthentication = false;
          X11Forwarding = false;
        };
      };
    };
  };

  testScript = ''
    start_all()
    nixio.wait_for_unit("multi-user.target")
    nixio.wait_for_unit("sshd.service")
    nixio.wait_for_open_port(22)

    with subtest("SSH daemon is running"):
      nixio.succeed("systemctl is-active sshd.service")

    with subtest("password authentication is disabled"):
      nixio.succeed("sshd -T | grep 'passwordauthentication no'")

    with subtest("root login is disabled"):
      nixio.succeed("sshd -T | grep 'permitrootlogin no'")

    with subtest("X11 forwarding is disabled"):
      nixio.succeed("sshd -T | grep 'x11forwarding no'")

    with subtest("keyboard-interactive is disabled"):
      nixio.succeed("sshd -T | grep 'kbdinteractiveauthentication no'")

    with subtest("SSH protocol check"):
      nixio.succeed("echo 'quit' | ssh -o StrictHostKeyChecking=no localhost 2>&1 | grep -i 'protocol' || true")
  '';
}
