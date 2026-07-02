{
  nodes = {
    nixio = { ... }: {
      imports = [
        (import ../../../modules/nixos/server/network.nix {
          isThisIOPrimaryHost = true;
          getIOPrimaryHostAttr = _: [ ];
        })
      ];

      server.network = {
        subnets = [
          {
            dns = "10.0.1.2";
            domain = "subnet-a.internal";
            ipv4 = {
              cidr = "10.0.1.0/24";
            };
            ipv6 = {
              cidr = "fd00:a:1::/64";
            };
          }
          {
            dns = "10.0.2.2";
            domain = "subnet-b.internal";
            ipv4 = {
              cidr = "10.0.2.0/24";
            };
            ipv6 = {
              cidr = "fd00:a:2::/64";
            };
          }
        ];

        openPortsForSubnet = {
          tcp = [
            5432
            8080
          ];
          udp = [
            51820
            53
          ];
        };
      };

      networking.firewall.enable = true;
      services.openssh.enable = true;
    };
  };

  testScript = ''
    expected_v4 = {
      ("tcp", 5432, "10.0.1.0/24"),
      ("tcp", 5432, "10.0.2.0/24"),
      ("tcp", 8080, "10.0.1.0/24"),
      ("tcp", 8080, "10.0.2.0/24"),
      ("udp", 51820, "10.0.1.0/24"),
      ("udp", 51820, "10.0.2.0/24"),
      ("udp", 53, "10.0.1.0/24"),
      ("udp", 53, "10.0.2.0/24"),
    }

    expected_v6 = {
      ("tcp", 5432, "fd00:a:1::/64"),
      ("tcp", 5432, "fd00:a:2::/64"),
      ("tcp", 8080, "fd00:a:1::/64"),
      ("tcp", 8080, "fd00:a:2::/64"),
      ("udp", 51820, "fd00:a:1::/64"),
      ("udp", 51820, "fd00:a:2::/64"),
      ("udp", 53, "fd00:a:1::/64"),
      ("udp", 53, "fd00:a:2::/64"),
    }

    expected_ports = {5432, 8080, 51820, 53}
    cidrs_v4 = {"10.0.1.0/24", "10.0.2.0/24"}
    cidrs_v6 = {"fd00:a:1::/64", "fd00:a:2::/64"}

    def parse_nixosfw_rules(output, cidrs):
        found = set()
        for line in output.splitlines():
            parts = line.split()
            if len(parts) < 8:
                continue
            proto = None
            source = None
            dport = None
            for i, p in enumerate(parts):
                if p == "-p" and i + 1 < len(parts):
                    proto = parts[i + 1]
                elif p in ("-s", "--source") and i + 1 < len(parts):
                    source = parts[i + 1]
                elif p == "--dport" and i + 1 < len(parts):
                    dport = int(parts[i + 1])
            if proto and source and dport and source in cidrs:
                found.add((proto, dport, source))
        return found

    def dict_from_rules(rules):
        """Convert set of (proto,dport,source) to unique protocol list for assertion messages."""
        return sorted("  -p " + p + " --source " + s + " --dport " + str(d) for p, d, s in rules)

    def check_missing(found_expected, found_actual, label):
        missing = found_expected - found_actual
        if missing:
            raise AssertionError(label + " missing:\n" + "\n".join(dict_from_rules(missing)))

    def check_unexpected(found_expected, found_actual, label):
        extra = found_actual - found_expected
        if extra:
            raise AssertionError(label + " unexpected:\n" + "\n".join(dict_from_rules(extra)))

    with subtest("dump actual rules"):
      nixio.succeed("iptables -S nixos-fw >&2 || true")

    with subtest("subnet-scoped iptables rules"):
      out = nixio.succeed("iptables -S nixos-fw 2>/dev/null || true")
      found = parse_nixosfw_rules(out, cidrs_v4)
      check_missing(expected_v4, found, "IPv4")
      check_unexpected(expected_v4, found, "IPv4")

    with subtest("subnet-scoped ip6tables rules"):
      out = nixio.succeed("ip6tables -S nixos-fw 2>/dev/null || true")
      found = parse_nixosfw_rules(out, cidrs_v6)
      check_missing(expected_v6, found, "IPv6")
      check_unexpected(expected_v6, found, "IPv6")

    with subtest("no unexpected ports in subnet-scoped iptables rules"):
      out = nixio.succeed("iptables -S nixos-fw 2>/dev/null || true")
      for proto, dport, source in parse_nixosfw_rules(out, cidrs_v4):
          assert dport in expected_ports, (
              "Unexpected port " + str(dport) + "/" + proto
              + " for subnet " + source
          )

    with subtest("extraCommands and extraStopCommands in generated unit"):
      unit_path = nixio.succeed(
          "systemctl show -p FragmentPath firewall.service 2>/dev/null"
          + " | cut -d= -f2"
      ).strip()
      assert unit_path, "firewall.service not found"

      # Pull ExecStart and ExecStop paths from unit, then read their content.
      exec_start = nixio.succeed(
          "grep 'ExecStart=' " + unit_path + " | head -1 | sed 's/.*=@//' | cut -d' ' -f1"
      ).strip()
      exec_stop = nixio.succeed(
          "grep 'ExecStop=' " + unit_path + " | head -1 | sed 's/.*=@//' | cut -d' ' -f1"
      ).strip()
      assert exec_start, "no ExecStart found in unit"
      assert exec_stop, "no ExecStop found in unit"
      nixio.succeed("cat " + exec_start + " >&2")
      nixio.succeed("cat " + exec_stop + " >&2")
      start_content = nixio.succeed("cat " + exec_start + " 2>/dev/null || true")
      stop_content = nixio.succeed("cat " + exec_stop + " 2>/dev/null || true")

      expected_add = [
          "iptables -A nixos-fw -p tcp --source 10.0.1.0/24 --dport 5432 -j nixos-fw-accept",
          "iptables -A nixos-fw -p tcp --source 10.0.2.0/24 --dport 5432 -j nixos-fw-accept",
          "iptables -A nixos-fw -p tcp --source 10.0.1.0/24 --dport 8080 -j nixos-fw-accept",
          "iptables -A nixos-fw -p tcp --source 10.0.2.0/24 --dport 8080 -j nixos-fw-accept",
          "iptables -A nixos-fw -p udp --source 10.0.1.0/24 --dport 51820 -j nixos-fw-accept",
          "iptables -A nixos-fw -p udp --source 10.0.2.0/24 --dport 51820 -j nixos-fw-accept",
          "iptables -A nixos-fw -p udp --source 10.0.1.0/24 --dport 53 -j nixos-fw-accept",
          "iptables -A nixos-fw -p udp --source 10.0.2.0/24 --dport 53 -j nixos-fw-accept",
      ]
      for cmd in expected_add:
          assert cmd in start_content, "extraCommands missing: " + cmd

      expected_del = [
          "iptables -D nixos-fw -p tcp --source 10.0.1.0/24 --dport 5432 -j nixos-fw-accept || true",
          "iptables -D nixos-fw -p tcp --source 10.0.2.0/24 --dport 5432 -j nixos-fw-accept || true",
          "iptables -D nixos-fw -p tcp --source 10.0.1.0/24 --dport 8080 -j nixos-fw-accept || true",
          "iptables -D nixos-fw -p tcp --source 10.0.2.0/24 --dport 8080 -j nixos-fw-accept || true",
          "iptables -D nixos-fw -p udp --source 10.0.1.0/24 --dport 51820 -j nixos-fw-accept || true",
          "iptables -D nixos-fw -p udp --source 10.0.2.0/24 --dport 51820 -j nixos-fw-accept || true",
          "iptables -D nixos-fw -p udp --source 10.0.1.0/24 --dport 53 -j nixos-fw-accept || true",
          "iptables -D nixos-fw -p udp --source 10.0.2.0/24 --dport 53 -j nixos-fw-accept || true",
      ]
      for cmd in expected_del:
          assert cmd in stop_content, "extraStopCommands missing: " + cmd
  '';
}
