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
      kanidm ? null,
    }:
    {
      inherit
        service
        port
        grpcPort
        aliases
        kanidm
        ;
      withGrpc = grpcPort != null;
    };

  mkVHost =
    subdomain: attr:
    nameValuePair subdomain {
      aliases = attr.aliases or [ ];
      ports = [ attr.port ];
      kanidm = attr.kanidm or null;
      extraConfig = ''
        reverse_proxy http://127.0.0.1:${toString attr.port}
      '';
    };

  mkVHostGrpcFor =
    hostname: attr:
    nameValuePair "${hostname}:10443" {
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

        reverse_proxy 127.0.0.1:${toString attr.grpcPort} {
          transport http {
            tls_trust_pool file ${config.sops.secrets."SEAWEEDFS/TLS/CA".path}
            tls_server_name "${hostname}.${self.data.site.domain}"
            tls_client_auth ${config.sops.secrets."SEAWEEDFS/TLS/${toUpper attr.service}_CRT".path} ${
              config.sops.secrets."SEAWEEDFS/TLS/${toUpper attr.service}_KEY".path
            }
          }
        }
      '';
    };

  # Aliases are bare subdomains; the vhost module derives the base URL from the name.
  # They keep the previous gRPC hostname serving the same backend,
  # so a rename does not cut off clients that still dial the old name.
  mkVHostGrpc =
    domain: attr: map (hostname: mkVHostGrpcFor hostname attr) ([ domain ] ++ attr.aliases);

  proxyEntries =
    (optionalAttrs cfg.master.enable {
      "master.seaweedfs" = mkProxyEntry {
        service = "master";
        port = cfg.master.port;
        grpcPort = cfg.master.grpcPort;
        aliases = [ "seaweedfs" ];
        kanidm = {
          context = "seaweedfs";
          protectedPaths = [ "/*" ];
          bypassPaths = [
            "/healthz"
            "/readyz"
          ];
        };
      };
    })
    // (optionalAttrs cfg.filer.enable {
      "filer.seaweedfs" = mkProxyEntry {
        service = "filer";
        port = cfg.filer.port;
        grpcPort = cfg.filer.grpcPort;
        kanidm = {
          context = "seaweedfs";
        };
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
        kanidm = {
          context = "seaweedfs";
          protectedPaths = [
            "/ui/*"
            "/status"
          ];
        };
      };
    })
    // (optionalAttrs cfg.admin.enable {
      "admin.seaweedfs" = mkProxyEntry {
        service = "admin";
        port = cfg.admin.port;
        grpcPort = cfg.admin.grpcPort;
        kanidm = {
          context = "seaweedfs";
          logoutPath = "/logout";
        };
      };
    });

  hasAnyGrpcVhosts = proxyEntries |> attrsToList |> builtins.any (entry: entry.value.withGrpc);
in
{
  config = mkIf swLib.isEnabled (mkMerge [
    {
      server.proxy.kanidmContexts.seaweedfs = {
        allowGroups = [ "sysadmin@auth.racci.dev" ];
        sharedPortal = true;
        cookieDomain = "seaweedfs.${self.data.site.domain}";
      };

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
