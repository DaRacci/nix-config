{
  getIOPrimaryHostAttr,
  ...
}:
{
  lib,
  ...
}:
let
  inherit (lib)
    mkBefore
    mkOption
    types
    ;
  inherit (types)
    str
    int
    bool
    port
    nullOr
    listOf
    attrsOf
    submodule
    literalExpression
    ;

  kanidmContextOptions = _: {
    options = {
      authDomain = mkOption {
        type = nullOr str;
        default = null;
        example = "auth.example.com";
        description = "The domain where Kanidm is hosted. Defaults to auth.<server.proxy.domain> if not specified.";
      };

      scopes = mkOption {
        type = listOf str;
        default = [
          "openid"
          "email"
          "profile"
          "groups"
        ];
        description = "OAuth scopes to request from Kanidm.";
      };

      tokenLifetime = mkOption {
        type = int;
        default = 3600;
        description = "Token lifetime in seconds for the authentication portal.";
      };

      allowGroups = mkOption {
        type = listOf str;
        default = [ ];
        example = [
          "idm_all_persons@auth.racci.dev"
          "admins@auth.racci.dev"
        ];
        description = "Default list of Kanidm groups allowed to access virtualHosts using this context.";
      };
    };
  };
in
{
  options.server.proxy = {
    domain = mkOption {
      type = str;
      description = "The base domain for all virtual hosts.";
    };

    kanidmContexts = mkOption {
      description = "Shared Kanidm OAuth2 context configurations.";
      default = { };
      example = literalExpression ''
        {
          arr-services = {
            scopes = [ "openid" "email" "profile" "groups" ];
            tokenLifetime = 7200;
          };
          admin-apps = {
            authDomain = "auth.internal.example.com";
            tokenLifetime = 1800;
            allowGroups = [ "admin@auth.internal.example.com" ];
          };
        }
      '';
      type = attrsOf (submodule kanidmContextOptions);
    };

    virtualHosts = mkOption {
      description = "Virtual hosts to be handled by the IO server and forwarded to the respective backend.";
      default = { };
      type = attrsOf (
        submodule (
          { name, ... }:
          {
            options = {
              aliases = mkOption {
                type = listOf str;
                default = [ ];
                description = ''
                  A list of virtual host names that should be routed using this configuration.
                  Options added here will inherit the base domain specificed in <server.proxy.domain>.
                '';
                apply = list: map (alias: "${alias}.${getIOPrimaryHostAttr "server.proxy.domain"}") list;
              };

              public = mkOption {
                type = bool;
                default = false;
                description = "When enabled this service will be accessible to the public via Cloudflared Tunnels.";
              };

              baseUrl = mkOption {
                type = str;
                default = "${name}.${getIOPrimaryHostAttr "server.proxy.domain"}";
                description = "The base url including the configured base domain name.";
                readOnly = true;
              };

              ports = mkOption {
                type = listOf port;
                default = [ ];
                description = "Ports to be opened from the host for IO Hosts to forward traffic to.";
              };

              extraConfig = mkOption {
                type = str;
                default = "";
                description = "Configuration to be placed in the caddy virtualHost extraConfig.";
              };

              l4 = mkOption {
                default = null;
                type = nullOr (submodule {
                  options = {
                    listenPort = mkOption {
                      type = port;
                      description = "Port to listen on for L4 traffic.";
                    };

                    config = mkOption {
                      type = str;
                      default = "";
                      description = "Configuration for the L4 plugin.";
                    };
                  };
                });
              };

              kanidm = mkOption {
                default = null;
                description = "Enable Kanidm OAuth2 authentication for this virtual host.";
                type = nullOr (submodule {
                  options = {
                    context = mkOption {
                      type = str;
                      default = name;
                      description = "The OAuth context name for this virtual host.";
                    };

                    authDomain = mkOption {
                      type = nullOr str;
                      default = null;
                      example = "auth.example.com";
                      description = "The domain where Kanidm is hosted.";
                    };

                    scopes = mkOption {
                      type = nullOr (listOf str);
                      default = null;
                      example = [
                        "openid"
                        "email"
                        "profile"
                        "groups"
                      ];
                      description = "OAuth scopes to request from Kanidm.";
                    };

                    allowGroups = mkOption {
                      type = listOf str;
                      example = [
                        "idm_all_persons@auth.racci.dev"
                        "admins@auth.racci.dev"
                      ];
                      description = "List of Kanidm groups allowed to access this virtual host.";
                    };

                    bypassPaths = mkOption {
                      type = listOf str;
                      default = [ ];
                      example = [
                        "/health"
                        "/api/webhooks/*"
                      ];
                      description = "List of path patterns that should bypass authentication.";
                    };

                    tokenLifetime = mkOption {
                      type = nullOr int;
                      default = null;
                      example = 7200;
                      description = "Token lifetime in seconds for the authentication portal.";
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
}
