{
  self,
  config,
  lib,
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

  config = mkIf (!isNixio) {
    server.network.subnets = self.nixosConfigurations.nixio.config.server.network.subnets;
  };
}
