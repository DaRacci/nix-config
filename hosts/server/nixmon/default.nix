_: {
  sops.secrets = { };

  server = {
    dashboard = {
      icon = "mdi-monitor-dashboard";
      items.uptime = {
        title = "Uptime Kuma";
        icon = "sh-uptime-kuma";
      };
      items.grafana = {
        title = "Grafana";
        icon = "sh-grafana";
      };
    };

    proxy.virtualHosts = {
      uptime.extraConfig = ''
        reverse_proxy http://localhost:3001
      '';
    };
  };

  services = {
    uptime-kuma = {
      enable = true;
      appriseSupport = true;
      settings = {
        HOST = "::";
      };
    };
  };

  server.tests.units = {
    prometheus = {
      testScript = ''
        nixmon.wait_for_unit("prometheus.service")
        nixmon.wait_for_open_port(9090)
        nixmon.succeed("curl -s http://localhost:9090/api/v1/status/buildinfo")
      '';
    };

    loki = {
      testScript = ''
        nixmon.succeed("systemctl show loki.service | grep -i loadstate")
      '';
    };

    grafana = {
      testScript = ''
        nixmon.succeed("systemctl show grafana.service | grep -i loadstate")
      '';
    };

    alertmanager = {
      testScript = ''
        nixmon.succeed("systemctl show alertmanager.service | grep -i loadstate")
      '';
    };

    uptime-kuma = {
      testScript = ''
        nixmon.succeed("systemctl show uptime-kuma.service | grep -i loadstate")
      '';
    };

    node-exporter = {
      testScript = ''
        nixmon.succeed("systemctl show node_exporter.service | grep -i loadstate")
      '';
    };

    alloy = {
      testScript = ''
        nixmon.succeed("systemctl show alloy.service | grep -i loadstate")
      '';
    };
  };

  networking.firewall.allowedTCPPorts = [ 3001 ];
}
