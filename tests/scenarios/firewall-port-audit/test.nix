# Firewall Port Audit Scenario
# Compares listening ports against declared firewall rules.
{
  nodes = {
    nixio = _: {
      services.openssh.enable = true;
      networking.firewall.enable = true;
      networking.firewall.allowedTCPPorts = [
        22
        80
        443
      ];
    };
  };

  testScript = ''
    start_all()
    nixio.wait_for_unit("multi-user.target")

    with subtest("declared ports are open"):
      nixio.succeed("iptables -L nixos-fw -n | grep 'tcp dpt:22'")
      nixio.succeed("iptables -L nixos-fw -n | grep 'tcp dpt:80'")
      nixio.succeed("iptables -L nixos-fw -n | grep 'tcp dpt:443'")

    with subtest("no unexpected listeners on high ports"):
      out = nixio.succeed("ss -tlnp | awk '{print $4}' | grep -oP ':\\d+' | grep -oP '\\d+'")
      for port in out.splitlines():
        assert int(port) < 10000, f"unexpected listener on port {port}"
  '';
}
