{
  self,
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkOption mkIf;
  inherit (lib.types)
    submodule
    str
    listOf
    nullOr
    ;

  isNixio = config.host.name == "nixio";
  nixioConfig = self.nixosConfigurations.nixio.config;
  getNixioConfig =
    attrPath:
    let
      configuration = if isNixio then config else nixioConfig;
      attrs = lib.splitString "." attrPath;
    in
    lib.lists.foldl' (acc: attr: acc.${attr}) configuration attrs;

  importModule = path: import path { inherit isNixio nixioConfig getNixioConfig; };

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
  imports = [
    (importModule ./dashboard.nix)
    (importModule ./database.nix)
    (importModule ./proxy.nix)
  ];

  options = {
    server.network = {
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
  };

  config = lib.mkMerge [
    (mkIf (!isNixio) {
      server.network.subnets = self.nixosConfigurations.nixio.config.server.network.subnets;
    })
    {
      services.journald = {
        storage = "persistent";
        extraConfig = ''
          SystemMaxUse=256M
          SystemMaxFileSize=64M
          SystemKeepFree=512M
          MaxRetentionSec=14day
        '';
      };
    }
    (mkIf (!isNixio) {
      systemd.services.wait-for-nixio = {
        description = "Wait for nixio host to become reachable";
        after = [ "dhcpd.service" ];
        wants = [
          "network.target"
          "dhcpd.service"
        ];
        before = [ "network-online.target" ];
        requiredBy = [ "network-online.target" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${pkgs.bash}/bin/bash -e -c 'for i in {1..150}; do if getent hosts nixio >/dev/null 2>&1 && ping -c1 -W1 nixio >/dev/null 2>&1; then exit 0; fi; sleep 2; done; echo \"nixio not reachable after timeout\" >&2; exit 1'";
        };
      };
    })
  ];
}
