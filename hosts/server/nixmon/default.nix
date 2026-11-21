{
  config,
  ...
}:
{
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

  server.network.openPortsForSources.${config.server.ioPrimaryHost}.tcp = [ 3001 ];
}
