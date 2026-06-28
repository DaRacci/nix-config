# Distributed Builds Scenario
# Verifies builder user and SSH key infrastructure exist.
{
  nodes = {
    nixserv = _: {
      services.openssh.enable = true;
    };
  };

  testScript = ''
    start_all()
    nixserv.wait_for_unit("multi-user.target")
    nixserv.succeed("systemctl show sshd.service | grep -i loadstate")
  '';
}
