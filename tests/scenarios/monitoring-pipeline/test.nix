# Monitoring Pipeline Scenario — Test Script
{
  nodes = (import ./default.nix).nodes;

  testScript = ''
    import json

    start_all()

    with subtest("nixmon baseline"):
      nixmon.wait_for_unit("multi-user.target")
      nixmon.wait_for_unit("sshd.service")
      nixmon.succeed("journalctl --no-pager -n 1")
      out = nixmon.succeed("systemctl list-units --state=failed --no-legend --no-pager")
      assert out.strip() == "", f"Failed units on nixmon: {out}"

    with subtest("nixio baseline"):
      nixio.wait_for_unit("multi-user.target")
      nixio.wait_for_unit("sshd.service")
      nixio.succeed("journalctl --no-pager -n 1")
      out = nixio.succeed("systemctl list-units --state=failed --no-legend --no-pager")
      assert out.strip() == "", f"Failed units on nixio: {out}"

    with subtest("prometheus and loki come up on nixmon"):
      nixmon.wait_for_unit("prometheus.service")
      nixmon.wait_for_unit("loki.service")
      nixmon.wait_for_open_port(9090)
      nixmon.wait_for_open_port(3100)

    with subtest("exporters come up on nixio"):
      nixio.wait_for_unit("prometheus-node-exporter.service")
      nixio.wait_for_open_port(9100)

    with subtest("caddy on nixio, caddy exporter active"):
      nixio.wait_for_unit("caddy.service")
      nixio.wait_for_open_port(2015)
      nixio.sleep(2)
      out = nixio.succeed("curl -s http://localhost:2015/metrics 2>&1 | head -5")
      print(f"caddy metrics: {out}")

    with subtest("prometheus scrape targets include nixio exporters"):
      nixmon.sleep(40)
      targets_raw = nixmon.succeed(
          "curl -s http://127.0.0.1:9090/api/v1/targets"
      )
      targets = json.loads(targets_raw)
      assert targets["status"] == "success", f"Prom API error: {targets_raw}"

      instances = []
      for t in targets["data"]["activeTargets"]:
          labels = t["discoveredLabels"]
          addr = labels.get("__address__", "")
          instances.append(addr)

      node_t = [i for i in instances if ":9100" in i]
      caddy_t = [i for i in instances if ":3019" in i]
      pg_t = [i for i in instances if ":9187" in i]

      assert len(node_t) >= 1, f"node target not found in {instances}"
      assert len(caddy_t) >= 1, f"caddy target not found in {instances}"
      assert len(pg_t) >= 1, f"postgres target not found in {instances}"

    with subtest("alert rules loaded in prometheus"):
      rules_raw = nixmon.succeed(
          "curl -s http://127.0.0.1:9090/api/v1/rules"
      )
      rules = json.loads(rules_raw)
      assert rules["status"] == "success", f"Rules API error: {rules_raw}"
      groups = rules["data"].get("groups", [])
      assert len(groups) >= 1, f"no rule groups found: {rules_raw}"

    with subtest("log shipping: write log on nixio, query from loki on nixmon"):
      test_msg = "monitoring-pipeline-test-log-line-42"
      nixio.succeed(f"logger '{test_msg}'")
      nixio.sleep(8)

      loki_resp = nixmon.succeed(
          "curl -s --data-urlencode 'query={host=\"nixio\"}|=\"monitoring-pipeline-test-log-line-42\"' "
          "'http://127.0.0.1:3100/loki/api/v1/query_range'"
      )
      loki_data = json.loads(loki_resp)
      assert loki_data["status"] == "success", f"Loki query error: {loki_resp}"
      result_count = len(loki_data["data"].get("result", []))
      assert result_count >= 1, f"log line not found in Loki: {loki_resp}"
  '';
}
