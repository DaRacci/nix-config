{
  isIOPrimaryHost,
  isThisIOPrimaryHost,
  getIOPrimaryHostAttr,

  collectAllAttrsFunc,
  ...
}:
{
  config,
  lib,
  ...
}:
let
  inherit (lib)
    flatten
    hasSuffix
    mapAttrs'
    mkDefault
    mkIf
    mkMerge
    mkOption
    nameValuePair
    optionalString
    types
    unique
    ;
  cfg = config.server.proxy;

  replaceLocalHost =
    host: str:
    if isIOPrimaryHost host then
      str
    else
      builtins.replaceStrings [
        "localhost"
        "0.0.0.0"
        "127.0.0.1"
        "[::]"
        "[::1]"
        "::1"
      ] (builtins.genList (_: host) 6) str;
in
{
  options.server.proxy = with types; {
    domain = mkOption {
      type = str;
      description = ''
        The base domain for all virtual hosts.
      '';
    };

    virtualHosts = mkOption {
      description = ''
        Virtual hosts to be handled by the IO server and forwarded to the respective backend.

        All virtual hosts are also added to acme for automatic certificate management.

        Each virtual host will have the value configured in <server.proxy.domain> added as the basedomain,
        with this attributes name as the subdomain.

        Defining virtualHosts on any machine except an IO Host will do nothing on that machine but are instead aggregated to the IO Hosts.
      '';
      default = { };
      type = attrsOf (
        submodule (
          { name, ... }:
          {
            options = {
              public = mkOption {
                type = bool;
                default = false;
                description = ''
                  When enabled this service will be accessible to the public via Cloudflared Tunnels.
                  Traffic will still be routed through caddy.
                '';
              };

              baseUrl = mkOption {
                type = str;
                default = "${name}.${getIOPrimaryHostAttr "server.proxy.domain"}";
                description = ''
                  The base url including the configured base domain name.
                '';
                readOnly = true;
              };

              ports = mkOption {
                type = types.listOf types.port;
                default = [ ];
                description = ''
                  Ports to be opened from the host for IO Hosts to forward traffic to.

                  These ports will only accept traffic from the defined subnets for security.
                '';
              };

              extraConfig = mkOption {
                type = nullOr str;
                default = null;
                description = ''
                  Configuration to be placed in `<services.caddy.virtualHosts.${name}.extraConfig>`

                  This configuration is parsed and the following are applied to the content:
                  - Rewrite localhost/127.0.0.1/0.0.0.0 to the machines domain name.
                '';
              };

              l4 = mkOption {
                default = null;
                type = nullOr (submodule {
                  options = {
                    listenPort = mkOption {
                      type = types.port;
                      default = null;
                      description = "Port to listen on for L4 traffic";
                    };

                    config = mkOption {
                      type = str;
                      default = "";
                      description = "Configuration for the L4 plugin";
                    };
                  };
                });
              };
            };
          }
        )
      );
    };
  };

  config = mkMerge [
    {
      server.dashboard.items = builtins.mapAttrs (name: cfg: {
        title = mkDefault (lib.mine.strings.capitalise name);
        url = mkDefault "https://${cfg.baseUrl}/";
        icon = mkDefault "sh-${name}"; # Guess an icon name, should work for most common services
      }) cfg.virtualHosts;
    }

    (mkIf (!isThisIOPrimaryHost) {
      server.network.openPortsForSubnet.tcp =
        cfg.virtualHosts |> builtins.attrValues |> map (vh: vh.ports) |> flatten |> unique;
    })

    (mkIf isThisIOPrimaryHost {
      services.caddy = {
        globalConfig = ''
          layer4 {
            ${
              collectAllAttrsFunc "server.proxy.virtualHosts" (
                virtualHosts: cfg:
                virtualHosts
                |> builtins.attrValues
                |> builtins.filter (vh: vh.l4 != null)
                |> builtins.map (vh: ''
                  ${vh.baseUrl}:${toString vh.l4.listenPort} {
                    ${replaceLocalHost cfg.host.name vh.l4.config}
                  }
                '')
              )
              |> builtins.concatStringsSep "\n"
            }
          }
        '';

        virtualHosts = collectAllAttrsFunc "server.proxy.virtualHosts" (
          virtualHosts: cfg:
          mapAttrs' (
            _: vh:
            lib.nameValuePair vh.baseUrl {
              hostName = vh.baseUrl;
              useACMEHost = vh.baseUrl;
              extraConfig = ''
                import default
                ${optionalString vh.public "import public"}
                ${optionalString (vh.extraConfig != null) (replaceLocalHost cfg.host.name vh.extraConfig)}
              '';
            }
          ) virtualHosts
        );
      };

      services.cloudflared.tunnels."8d42e9b2-3814-45ea-bbb5-9056c8f017e2" =
        let
          publicHosts = collectAllAttrsFunc "server.proxy.virtualHosts" (
            vh: _:
            builtins.attrValues vh
            |> builtins.filter (vh: vh.public)
            |> builtins.map (vh: nameValuePair vh.baseUrl "https://${vh.baseUrl}")
            |> builtins.listToAttrs
          );
        in
        mkIf ((builtins.attrValues publicHosts |> builtins.length) > 0) {
          ingress = publicHosts;
        };

      security.acme.certs =
        builtins.attrNames config.services.caddy.virtualHosts
        |> builtins.filter (name: hasSuffix ".${cfg.domain}" name)
        |> map (name: lib.nameValuePair name { })
        |> builtins.listToAttrs;

      networking.firewall = rec {
        allowedTCPPorts = collectAllAttrsFunc "server.proxy.virtualHosts" (
          virtualHosts: _:
          builtins.attrValues virtualHosts
          |> builtins.filter (vh: vh.l4 != null)
          |> map (vh: vh.l4.listenPort)
        );
        allowedUDPPorts = allowedTCPPorts;
      };
    })
  ];
}
