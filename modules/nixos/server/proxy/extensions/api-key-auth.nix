{
  isThisIOPrimaryHost,
  collectAllAttrsFunc,
  getAllAttrsFunc,
  ...
}:
{
  config,
  lib,
  ...
}:
let
  inherit (lib)
    mkDefault
    mkIf
    mkOption
    toUpper
    types
    optionalString
    ;

  inherit (types)
    attrsOf
    bool
    listOf
    nullOr
    str
    submodule
    ;

  sanitiseName = name: builtins.replaceStrings [ "-" "." ] [ "_" "_" ] name;

  envVarName = name: "API_KEY_${toUpper (sanitiseName name)}";

  hasAnyApiKey =
    getAllAttrsFunc "server.proxy.virtualHosts" (
      virtualHosts: _: virtualHosts |> builtins.attrValues |> builtins.any (vh: vh.requireApiKey.enable)
    )
    |> builtins.any (x: x);

  collectApiKeyVirtualHosts = collectAllAttrsFunc "server.proxy.virtualHosts" (
    virtualHosts: _: virtualHosts |> lib.filterAttrs (_: vh: vh.requireApiKey.enable)
  );
in
{
  options.server.proxy.virtualHosts = mkOption {
    type = attrsOf (
      submodule (_: {
        options.requireApiKey = mkOption {
          default = null;
          type = nullOr (submodule {
            options = {
              enable = mkOption {
                type = bool;
                default = false;
                description = "Enable API key authentication for this virtual host.";
              };

              bypassPaths = mkOption {
                type = listOf str;
                default = [ ];
                example = [
                  "/health"
                  "/api/webhooks/*"
                ];
                description = "List of path patterns that bypass API key authentication.";
              };
            };
          });
        };
      })
    );
  };

  config = {
    server.proxy.extensions.api-key-auth = {
      priority = 50;
      consumesExtraConfig = true;
      enable = mkDefault hasAnyApiKey;

      config =
        name: vh: _hostCfg:
        if vh.requireApiKey.enable then
          let
            sname = sanitiseName name;
            upperName = toUpper sname;
          in
          ''
            ${optionalString (vh.requireApiKey.bypassPaths != [ ]) ''
              @bypass_apikey_${sname} path ${builtins.concatStringsSep " " vh.requireApiKey.bypassPaths}
              handle @bypass_apikey_${sname} {
                ${vh._resolvedExtraConfig}
              }
            ''}
            @${sname}_apikey_key {
              header Req-API-Key {env.API_KEY_${upperName}}
            }
            route /auth/apikey/* {
              authorize with ${sname}_apikey_authorizer
            }
            handle {
              authorize with ${sname}_apikey_authorizer
              ${vh._resolvedExtraConfig}
            }
          ''
        else
          "";

      globalConfig =
        _hostCfg:
        let
          apiKeyVhosts = collectApiKeyVirtualHosts;
        in
        optionalString (apiKeyVhosts != { }) ''
          ${optionalString (
            !config.server.proxy.extensions.kanidm.enable
          ) "order authorize before reverse_proxy"}
          ${builtins.concatStringsSep "\n" (
            builtins.attrValues (
              builtins.mapAttrs (name: _vh: ''
                authorize with ${sanitiseName name}_apikey_authorizer {
                  with @${sanitiseName name}_apikey_key
                }
              '') apiKeyVhosts
            )
          )}
        '';

      vhostModule = null;
    };

    sops.secrets = mkIf (isThisIOPrimaryHost && hasAnyApiKey) (
      let
        apiKeyVhosts = collectApiKeyVirtualHosts;
      in
      builtins.listToAttrs (
        builtins.attrNames apiKeyVhosts
        |> map (name: {
          name = "PROXY_AUTH/${toUpper (sanitiseName name)}_API_KEY";
          value = {
            owner = "caddy";
            group = "caddy";
            mode = "0400";
          };
        })
      )
    );

    systemd.services.caddy.serviceConfig.LoadCredential = mkIf (isThisIOPrimaryHost && hasAnyApiKey) (
      let
        apiKeyVhosts = collectApiKeyVirtualHosts;
      in
      builtins.attrNames apiKeyVhosts
      |> map (
        name:
        "${envVarName name}:${config.sops.secrets."PROXY_AUTH/${toUpper (sanitiseName name)}_API_KEY".path}"
      )
    );
  };
}
