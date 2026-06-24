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
    mkOption
    types
    literalExpression
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
    nonEmptyListOf
    functionTo
    deferredModule
    ;

in
{
  options.server.proxy = {
    domain = mkOption {
      type = str;
      description = "The base domain for all virtual hosts.";
    };

    extensions = mkOption {
      description = "Registry of proxy extensions. Each extension provides config functions that are injected into vhost Caddy blocks, sorted by priority.";
      default = { };
      type = attrsOf (
        submodule (_: {
          options = {
            priority = mkOption {
              type = int;
              default = 100;
              description = "Lower values = earlier in Caddy config. Priority ranges: 0-49 reserved, 50-99 auth, 100-199 general, 200+ post-processing.";
            };
            enable = mkOption {
              type = bool;
              default = false;
              description = ''
                Whether this extension is globally enabled.
                Each extension SHOULD auto-detect whether it has work to do and set this to `true` via `mkDefault` in its module config.
                User can explicitly override to force-disable (higher merge priority than mkDefault).
              '';
            };
            consumesExtraConfig = mkOption {
              type = bool;
              default = false;
              description = "Whether this extension embeds extraConfig inside its output. When true, config.nix skips the post-extension extraConfig append for this vhost.";
            };
            config = mkOption {
              type = functionTo (functionTo (functionTo str));
              description = "Function: vhostName -> vhostAttrSet -> hostConfig -> string. Returns Caddy directives to inject, or '' for no-op. The vhostAttrSet includes the resolved extraConfig (already localhost-replaced) as `_resolvedExtraConfig`.";
            };
            globalConfig = mkOption {
              type = functionTo str;
              default = _: "";
              description = "Function: hostConfig -> string. Returns Caddy directives to inject into the top-level globalConfig block. Only called on the IO primary host. Sorted by priority across extensions.";
            };
            vhostModule = mkOption {
              type = nullOr deferredModule;
              default = null;
              description = "Optional module to inject into each vhost submodule. Use `options.<extensionName>` (relative to vhost scope) to declare per-vhost options.";
            };
          };
        })
      );
    };

    virtualHosts = mkOption {
      description = "Virtual hosts to be handled by the IO server and forwarded to the respective backend.";
      default = { };
      type = attrsOf (
        submodule (
          { name, ... }:
          let
            split = lib.splitString ":" name;
            subdomain = builtins.head split;
            maybePort = if (builtins.length split) > 1 then lib.toInt (builtins.elemAt split 1) else null;
          in
          {
            options = {
              _name = mkOption {
                type = str;
                default = name;
                readOnly = true;
                internal = true;
                description = "The attribute name of this virtual host in the virtualHosts attrset.";
              };

              extensions = mkOption {
                type = nullOr (listOf str);
                default = null;
                description = ''
                  List of extension names to enable for this virtual host.
                  When null (default), all globally enabled extensions apply.
                  When set to a list, only those named extensions apply.
                  Set to [] to disable all extensions for this vhost.
                '';
              };
              aliases = mkOption {
                type = listOf str;
                default = [ ];
                description = ''
                  A list of virtual host names that should be routed using this configuration.
                  Options added here will inherit the base domain specified in <server.proxy.domain>.
                '';
                apply = list: map (alias: "${alias}.${getIOPrimaryHostAttr "server.proxy.domain"}") list;
              };

              listenPorts = mkOption {
                type = nonEmptyListOf port;
                default = if maybePort != null then [ maybePort ] else [ 443 ];
                description = ''
                  Port(s) to listen on for incoming traffic for this virtual host.
                  If multiple ports are specified, the virtual host will be accessible on all of them.
                '';
              };

              useAcmeCerts = mkOption {
                type = bool;
                default = true;
                description = ''
                  Whether to generate and use ACME certificates for this virtual host.
                  If false, you must provide your own TLS configuration in extraConfig via the caddy tls directive.
                '';
              };

              public = mkOption {
                type = bool;
                default = false;
                description = "When enabled this service will be accessible to the public via Cloudflared Tunnels.";
              };

              baseUrl = mkOption {
                type = str;
                default = "${subdomain}.${getIOPrimaryHostAttr "server.proxy.domain"}";
                defaultText = literalExpression ''
                  ''${subdomain}.''${getIOPrimaryHostAttr "server.proxy.domain"}
                '';
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
            };
          }
        )
      );
    };
  };
}
