{
  self,
  config,
  lib,
  ...
}:
let
  inherit (lib)
    concatStringsSep
    flatten
    mapAttrsToList
    mkIf
    mkMerge
    mkOption
    optionalString
    ;
  inherit (lib.types)
    attrsOf
    listOf
    port
    submodule
    ;

  cfg = config.server.network;
  cluster = self.data.network.cluster;
  clusterHost = cluster.hosts.${config.networking.hostName} or null;

  # Resolve a named source to the addresses and interface it lives on.
  resolveSource =
    source:
    if source == "cluster" then
      [
        {
          ipv6 = cluster.cidr;
          iface = "eth1";
        }
      ]
    else if source == "lan" then
      map (subnet: {
        ipv4 = subnet.ipv4.cidr;
        ipv6 = subnet.ipv6.cidr;
        iface = null;
      }) self.data.network.subnets
    else if cluster.hosts ? ${source} then
      [
        {
          ipv6 = cluster.hosts.${source};
          iface = "eth1";
        }
      ]
    else
      throw "server.network.openPortsForSources: unknown source '${source}'";

  mkSourceRules =
    source: sourceCfg:
    let
      ports =
        (map (port: {
          proto = "tcp";
          inherit port;
        }) sourceCfg.tcp)
        ++ (map (port: {
          proto = "udp";
          inherit port;
        }) sourceCfg.udp);
      rules = flatten (
        map (
          resolved:
          map (
            port:
            let
              iface = optionalString (resolved.iface != null) "iifname \"${resolved.iface}\" ";
              dport = toString port.port;
            in
            [
              (optionalString (
                (resolved.ipv4 or null) != null
              ) "${iface}ip saddr ${resolved.ipv4} ${port.proto} dport { ${dport} } accept")
              (optionalString (
                (resolved.ipv6 or null) != null
              ) "${iface}ip6 saddr ${resolved.ipv6} ${port.proto} dport { ${dport} } accept")
            ]
          ) ports
        ) (resolveSource source)
      );
    in
    builtins.filter (line: line != "") rules;
in
{
  options.server.network = {
    openPortsForSources = mkOption {
      default = { };
      type = attrsOf (submodule {
        options = {
          tcp = mkOption {
            default = [ ];
            type = listOf port;
            description = "List of TCP ports to open for this source.";
          };

          udp = mkOption {
            default = [ ];
            type = listOf port;
            description = "List of UDP ports to open for this source.";
          };
        };
      });
      description = ''
        Open ports for named sources.
        Host names resolve to their cluster address, `cluster` resolves to the
        cluster CIDR, and `lan` resolves to the external subnets.
      '';
    };
  };

  config = mkMerge [
    (mkIf (clusterHost != null) {
      networking.interfaces.eth1 = {
        useDHCP = false;
        ipv6.addresses = [
          {
            address = clusterHost;
            prefixLength = cluster.prefixLength;
          }
        ];
      };

      networking.extraHosts = concatStringsSep "\n" (
        mapAttrsToList (name: address: "${address} ${name}.${cluster.domain}") cluster.hosts
      );

      networking.search = [ cluster.domain ];
    })

    (
      let
        rules = flatten (
          mapAttrsToList (source: sourceCfg: mkSourceRules source sourceCfg) cfg.openPortsForSources
        );
        ruleset = concatStringsSep "\n" rules;
      in
      mkIf (rules != [ ]) {
        networking.firewall.extraInputRules = ruleset;
      }
    )
  ];
}
