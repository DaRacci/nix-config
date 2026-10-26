_:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    getExe
    mkIf
    optionals
    replaceStrings
    ;

  cfg = config.server.monitoring;
  isVirtual = config.host.device.isVirtual;

  textfileDir = "/var/lib/prometheus-node-exporter/textfile";

  # Prometheus label values escape backslash, quote, and newline.
  promLabel = value: replaceStrings [ "\\" "\"" "\n" ] [ "\\\\" "\\\"" "\\n" ] (toString value);

  nixosVersion = config.system.nixos.version;
  codeName = config.system.nixos.codeName;
  nixpkgsRevision =
    if config.system.nixos.revision != null then config.system.nixos.revision else "unknown";
  configurationRevision =
    if config.system.configurationRevision != null then
      config.system.configurationRevision
    else
      "unknown";

  nixosMetrics = pkgs.writeShellApplication {
    name = "nixos-system-metrics";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      set -euo pipefail

      out="''${STATE_DIRECTORY}/textfile/nixos.prom"
      mkdir -p "$(dirname "$out")"
      tmp="$out.tmp"

      install_timestamp=$(stat -c %Y /run/current-system)

      cat > "$tmp" <<EOF
      # HELP nixos_system_install_timestamp_seconds Unix timestamp of the current NixOS system activation.
      # TYPE nixos_system_install_timestamp_seconds gauge
      nixos_system_install_timestamp_seconds $install_timestamp
      # HELP nixos_system_build_info NixOS build metadata.
      # TYPE nixos_system_build_info gauge
      nixos_system_build_info{version="${promLabel nixosVersion}",code_name="${promLabel codeName}",nixpkgs_revision="${promLabel nixpkgsRevision}",configuration_revision="${promLabel configurationRevision}"} 1
      EOF

      mv "$tmp" "$out"
    '';
  };
in
{
  config = mkIf (cfg.enable && cfg.exporters.node.enable) {
    services.prometheus.exporters.node = {
      enable = true;
      port = 9100;
      listenAddress = "0.0.0.0";

      # enabledCollectors is additive, so defaults must be disabled explicitly.
      extraFlags = [
        "--collector.disable-defaults"
        "--collector.textfile.directory=${textfileDir}"
      ];

      enabledCollectors = [
        # Container-scoped and not covered by the Proxmox exporter.
        "filesystem"
        "systemd"

        # Required for nixos-system-metrics textfile ingestion.
        "textfile"
      ]
      ++ optionals (!isVirtual) [
        # These read host devices or kernel state that is either absent or not namespaced inside a container.
        "cpu"
        "meminfo"
        "netdev"
        "diskstats"
        "loadavg"
        "pressure"
        "stat"
        "time"
        "vmstat"
      ];
    };

    # node_exporter runs with ProtectSystem=strict, so give it a writable state directory for the textfile collector.
    systemd.services.prometheus-node-exporter.serviceConfig.StateDirectory = "prometheus-node-exporter";

    systemd.services.nixos-system-metrics = {
      description = "Write NixOS build metadata for node_exporter";
      wantedBy = [ "multi-user.target" ];
      before = [ "prometheus-node-exporter.service" ];

      serviceConfig = {
        Type = "oneshot";
        User = "node-exporter";
        Group = "node-exporter";
        StateDirectory = "prometheus-node-exporter";
        ExecStart = getExe nixosMetrics;
      };
    };

    server.network.openPortsForSubnet.tcp = [ config.services.prometheus.exporters.node.port ];
  };
}
