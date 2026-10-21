{
  isThisIOPrimaryHost,
  ...
}:
{
  config,
  lib,
  ...
}:
let
  inherit (lib)
    mkIf
    mkEnableOption
    mkOption
    flatten
    filterEmpty
    ;
  inherit (lib.types)
    port
    ;

  cfg = config.server.fail2ban;
in
{
  options.server.fail2ban = {
    enable = mkEnableOption "fail2ban intrusion detection" // {
      default = isThisIOPrimaryHost && config.services.caddy.enable;
      defaultText = lib.literalExpression "isThisIOPrimaryHost && config.services.caddy.enable";
    };

    exporterPort = mkOption {
      type = port;
      default = 9191;
      description = "Port for the fail2ban Prometheus exporter.";
    };
  };

  config = mkIf cfg.enable {
    services.fail2ban = {
      enable = true;

      ignoreIP =
        config.server.network.subnets
        |> map (subnet: [
          subnet.ipv4.cidr
          subnet.ipv6.cidr
        ])
        |> flatten
        |> filterEmpty;
      maxretry = 5;

      jails = {
        caddy-auth = {
          settings = {
            enabled = true;
            logpath = "/var/log/caddy/access-*.log";
            maxretry = 5;
          };
          filter.Definition = {
            failregex = ''^.*"remote_ip":"<HOST>",.*?"status":(?:401|403|500),.*$'';
            ignoreregex = "";
            datepattern = "LongEpoch";
          };
        };
      };
    };

    systemd.services.fail2ban.serviceConfig.SupplementaryGroups = [ "caddy" ];
  };
}
