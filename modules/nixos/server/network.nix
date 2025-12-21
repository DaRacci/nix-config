{
  isThisIOPrimaryHost,
  getIOPrimaryHostAttr,
  ...
}:
{
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
    submodule
    listOf
    nullOr
    port
    str
    ;

  cfg = config.server.network;

  ipOptions = submodule {
    options = {
      cidr = mkOption {
        default = null;
        type = nullOr str;
        description = "CIDR notation for the IP range.";
      };

      arpa = mkOption {
        default = null;
        type = nullOr str;
        description = "ARPA notation for reverse DNS lookups.";
      };
    };
  };
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

    subnets = mkOption {
      default = { };
      type = listOf (submodule {
        options = {
          dns = mkOption {
            type = str;
            description = "DNS server for the subnet.";
          };

          domain = mkOption {
            type = str;
            description = "Domain name for the subnet.";
          };

          ipv4 = mkOption {
            default = { };
            type = ipOptions;
            description = "IPv4 configuration for the subnet.";
          };

          ipv6 = mkOption {
            default = { };
            type = ipOptions;
            description = "IPv6 configuration for the subnet.";
          };
        };
      });
    };
  };

  config = mkMerge [
    (mkIf (!isThisIOPrimaryHost) {
      server.network.subnets = getIOPrimaryHostAttr "server.network.subnets";
    })

    (
      let
        openPorts = cfg.openPortsForSubnet;
        subnets = cfg.subnets;
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
        mkLines =
          delete: rule:
          builtins.filter (line: line != "") [
            (optionalString (rule.ipv4 != null)
              "iptables ${if delete then "-D" else "-A"} nixos-fw -p ${rule.proto} --source ${rule.ipv4} --dport ${toString rule.port} -j nixos-fw-accept${
                if delete then " || true" else ""
              }"
            )
            (optionalString (rule.ipv6 != null)
              "ip6tables ${if delete then "-D" else "-A"} nixos-fw -p ${rule.proto} --source ${rule.ipv6} --dport ${toString rule.port} -j nixos-fw-accept${
                if delete then " || true" else ""
              }"
            )
          ];
        mkCommands =
          delete: builtins.concatStringsSep "\n" (flatten (map (rule: mkLines delete rule) rules));
      in
      mkIf (rules != [ ]) {
        networking.firewall = {
          extraCommands = mkCommands false;
          extraStopCommands = mkCommands true;
        };
      }
    )
  ];
}
