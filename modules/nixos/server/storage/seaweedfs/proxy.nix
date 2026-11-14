{
  config,
  lib,
  self,
  ...
}:
let
  inherit (lib)
    attrsToList
    flatten
    mkIf
    mkMerge
    nameValuePair
    optionals
    optionalAttrs
    toUpper
    ;

  swLib = import ./lib.nix {
    inherit config lib self;
  };

  cfg = config.services.seaweedfs;

  mkProxyEntry =
    {
      service,
      port,
      grpcPort ? null,
      aliases ? [ ],
    }:
    {
      inherit
        service
        port
        grpcPort
        aliases
        ;
      withGrpc = grpcPort != null;
    };

  mkVHost =
    subdomain: attr:
    nameValuePair subdomain {
      aliases = attr.aliases or [ ];
      ports = [ attr.port ];
      # TODO: Secure behind kanidm.
      extraConfig = ''
        reverse_proxy http://localhost:${toString attr.port}
      '';
    };

  mkVHostGrpc =
    domain: attr:
    nameValuePair "${domain}:10443" {
      useAcmeCerts = false;
      ports = [ attr.grpcPort ];
      extraConfig = ''
        tls ${config.sops.secrets."SEAWEEDFS/TLS/${toUpper attr.service}_CRT".path} ${
          config.sops.secrets."SEAWEEDFS/TLS/${toUpper attr.service}_KEY".path
        } {
          protocols tls1.3
          ca_root ${config.sops.secrets."SEAWEEDFS/TLS/CA".path}
          client_auth {
            mode require_and_verify
            trusted_ca_cert_file ${config.sops.secrets."SEAWEEDFS/TLS/CA".path}
          }
        }

        reverse_proxy localhost:${toString attr.grpcPort} {
          transport http {
            tls_trust_pool file ${config.sops.secrets."SEAWEEDFS/TLS/CA".path}
            tls_server_name "${domain}.${self.data.site.domain}"
            tls_client_auth ${config.sops.secrets."SEAWEEDFS/TLS/${toUpper attr.service}_CRT".path} ${
              config.sops.secrets."SEAWEEDFS/TLS/${toUpper attr.service}_KEY".path
            }
          }
        }
      '';
    };

  proxyEntries =
    (optionalAttrs cfg.master.enable {
      seaweedfs = mkProxyEntry {
        service = "master";
        port = cfg.master.port;
        grpcPort = cfg.master.grpcPort;
      };
    })
    // (optionalAttrs cfg.filer.enable {
      "filer.seaweedfs" = mkProxyEntry {
        service = "filer";
        port = cfg.filer.port;
        grpcPort = cfg.filer.grpcPort;
      };
    })
    // (optionalAttrs (cfg.filer.enable && cfg.filer.s3.enable) {
      "s3.seaweedfs" = mkProxyEntry {
        service = "filer";
        port = cfg.filer.s3.port;
        aliases = [ "*.s3.seaweedfs" ];
      };
    })
    // (optionalAttrs cfg.volume.enable {
      "volume.seaweedfs" = mkProxyEntry {
        service = "volume";
        port = cfg.volume.port;
        grpcPort = cfg.volume.grpcPort;
      };
    })
    // (optionalAttrs cfg.admin.enable {
      "admin.seaweedfs" = mkProxyEntry {
        service = "admin";
        port = cfg.admin.port;
        grpcPort = cfg.admin.grpcPort;
      };
    });

  hasAnyGrpcVhosts = proxyEntries |> attrsToList |> builtins.any (entry: entry.value.withGrpc);
in
{
  config = mkIf swLib.isEnabled (mkMerge [
    {
      server.proxy.virtualHosts =
        proxyEntries
        |> attrsToList
        |> map (
          entry:
          [
            (mkVHost entry.name entry.value)
          ]
          ++ optionals entry.value.withGrpc [
            (mkVHostGrpc entry.name entry.value)
          ]
        )
        |> flatten
        |> builtins.listToAttrs;
    }

    (mkIf hasAnyGrpcVhosts {
      networking.firewall.allowedTCPPorts = [ 10443 ];
    })
  ]);
}
