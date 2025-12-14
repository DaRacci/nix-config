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

  importModule =
    path: inherits:
    import path (
      {
        inherit
          isNixio
          nixioConfig
          getNixioConfig
          importModule
          ;
      }
      // inherits
    );

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
    (importModule ./database { })
    (importModule ./dashboard.nix { })
    (importModule ./proxy.nix { })

    ./ssh
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
        wantedBy = [ "network-online.target" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = lib.getExe (
            pkgs.writeShellApplication {
              name = "wait-for-nixio";
              runtimeInputs = [
                pkgs.iputils
                pkgs.toybox
                pkgs.getent
              ];
              text = ''
                #shellcheck disable=SC2034
                for i in {1..150}; do
                  if getent hosts nixio >/dev/null 2>&1 && ping -c1 -W1 nixio >/dev/null 2>&1; then
                    exit 0;
                  fi;
                  sleep 2;
                done;
                echo "WARNING: nixio not reachable after timeout, continuing boot without nixio" >&2;
                exit 0
              '';
            }
          );
        };
      };
    })
  ];
}
