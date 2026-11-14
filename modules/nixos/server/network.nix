{
  self,
  config,
  lib,
  ...
}:
let
  inherit (lib)
    mkOption
    mkMerge
    mkIf
    flatten
    optionalString
    ;
  inherit (lib.types)
    listOf
    port
    ;

  cfg = config.server.network;
in
{
  options.server.network = {
    openPortsForSubnet = {
      tcp = mkOption {
        default = [ ];
        type = listOf port;
        description = "List of TCP ports to open on the firewall for each subnet.";
      };

      udp = mkOption {
        default = [ ];
        type = listOf port;
        description = "List of UDP ports to open on the firewall for each subnet.";
      };
    };
  };

  config = mkMerge [
    (
      let
        openPorts = cfg.openPortsForSubnet;
        subnets = self.data.network.subnets;
        mkRules =
          ports: proto:
          flatten (
            map (
              port:
              map (subnet: {
                inherit proto port;
                ipv4 = subnet.ipv4.cidr;
                ipv6 = subnet.ipv6.cidr;
              }) subnets
            ) ports
          );
        rules = builtins.filter (rule: rule.ipv4 != null || rule.ipv6 != null) (
          (mkRules openPorts.tcp "tcp") ++ (mkRules openPorts.udp "udp")
        );
        mkRule =
          rule:
          builtins.filter (line: line != "") [
            (optionalString (
              rule.ipv4 != null
            ) "ip saddr ${rule.ipv4} ${rule.proto} dport ${toString rule.port} accept")
            (optionalString (
              rule.ipv6 != null
            ) "ip6 saddr ${rule.ipv6} ${rule.proto} dport ${toString rule.port} accept")
          ];
        ruleset = builtins.concatStringsSep "\n" (flatten (map mkRule rules));
      in
      mkIf (rules != [ ]) {
        networking.firewall.extraInputRules = ruleset;
      }
    )
  ];
}
