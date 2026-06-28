# Monitoring Scrape Scenario
# Verifies nixmon prometheus scrapes a target on nixio.
{
  nodes = {
    nixmon = _: {
      services.prometheus = {
        enable = true;
        scrapeConfigs = [
          {
            job_name = "test-target";
            static_configs = [
              { targets = [ "nixio:9100" ]; }
            ];
          }
        ];
        globalConfig.scrape_interval = "5s";
      };
    };

    nixio = _: {
      services.prometheus.exporters.node = {
        enable = true;
        port = 9100;
        openFirewall = true;
      };
    };
  };

  testScript = ''
    start_all()

    with subtest("prometheus starts and serves API"):
      nixmon.wait_for_unit("prometheus.service")
      nixmon.wait_for_open_port(9090)
      nixmon.succeed("curl -s http://localhost:9090/api/v1/status/buildinfo")

    with subtest("node exporter serves metrics on nixio"):
      nixio.wait_for_unit("prometheus-node-exporter.service")
      nixio.wait_for_open_port(9100)
      nixio.succeed("curl -s http://localhost:9100/metrics | grep node_cpu")

    with subtest("prometheus discovers and scrapes target"):
      nixmon.succeed(
          "curl -s 'http://localhost:9090/api/v1/targets' | grep test-target"
      )
  '';
}
