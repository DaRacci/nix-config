{
  proxyLib,
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
    types
    mkDefault
    mkIf
    optionalString
    unique
    flatten
    ;

  inherit (types)
    str
    int
    nullOr
    listOf
    attrsOf
    submodule
    ;

  inherit (proxyLib)
    contextToEnvPrefix
    resolveKanidmContext
    hasAnyKanidm
    collectKanidmContexts
    collectKanidmVirtualHosts
    ;

  orderDirectives = ''
    order authenticate before respond
    order authorize before reverse_proxy
  '';

  generateIdentityProviders =
    contexts:
    contexts
    |> builtins.attrValues
    |> map (
      ctx:
      let
        envPrefix = contextToEnvPrefix ctx.context;
      in
      ''
        oauth identity provider ${ctx.context} {
          realm ${ctx.context}
          driver generic
          client_id "${ctx.context}"
          client_secret {env.OAUTH_${envPrefix}_CLIENT_SECRET}
          metadata_url https://${ctx.authDomain}/oauth2/openid/${ctx.context}/.well-known/openid-configuration
          scopes ${builtins.concatStringsSep " " ctx.scopes}
        }
      ''
    )
    |> builtins.concatStringsSep "\n";

  generateAuthenticationPortals =
    kanidmVirtualHosts:
    kanidmVirtualHosts
    |> builtins.attrNames
    |> map (
      name:
      let
        vh = kanidmVirtualHosts.${name};
        resolved = resolveKanidmContext name vh;
        envPrefix = contextToEnvPrefix resolved.context;
      in
      ''
        authentication portal ${name}_portal {
          crypto default token lifetime ${toString resolved.tokenLifetime}
          cookie domain "${resolved.cookieDomain}"
          crypto key sign-verify {env.${envPrefix}_SHARED_KEY}
          enable identity provider ${resolved.context}
        }
      ''
    )
    |> builtins.concatStringsSep "\n";

  generateAuthorizationPolicies =
    kanidmVirtualHosts:
    kanidmVirtualHosts
    |> builtins.attrNames
    |> map (
      name:
      let
        vh = kanidmVirtualHosts.${name};
        resolved = resolveKanidmContext name vh;
        envPrefix = contextToEnvPrefix resolved.context;
      in
      ''
        authorization policy ${name}_policy {
          set auth url https://${resolved.cookieDomain}/auth/oauth2/${resolved.context}
          crypto key sign-verify {env.${envPrefix}_SHARED_KEY}
          ${
            resolved.allowGroups |> map (group: "allow groups ${group}") |> builtins.concatStringsSep "\n    "
          }
        }
      ''
    )
    |> builtins.concatStringsSep "\n";

  commonKanidmOptions = {
    authDomain = mkOption {
      type = nullOr str;
      default = null;
      example = "auth.example.com";
      description = ''
        The domain where Kanidm is hosted.
        Defaults to auth.<server.proxy.domain> if not specified.
      '';
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

  kanidmContextsWithVirtualHosts =
    let
      contexts = collectKanidmContexts;
      virtualHosts = collectKanidmVirtualHosts;
    in
    builtins.mapAttrs (
      contextName: ctx:
      let
        vhsUsingContext = lib.filterAttrs (_: vh: vh.kanidm.context == contextName) virtualHosts;
        vhList = builtins.attrValues vhsUsingContext;
        allGroups =
          vhList
          |> map (vh: vh.kanidm.allowGroups)
          |> flatten
          |> unique;
        groupsWithoutDomain = allGroups |> map (g: builtins.head (lib.splitString "@" g));
      in
      ctx
      // {
        virtualHosts = vhsUsingContext;
        originUrls = map (
          vh: "https://${vh.baseUrl}/auth/oauth2/${contextName}/authorization-code-callback"
        ) vhList;
        originLanding = "https://${(builtins.head vhList).baseUrl}";
        groups = groupsWithoutDomain;
        inherit (ctx) scopes;
      }
    ) contexts;
in
{
  options = {
    server.proxy.kanidmContexts = mkOption {
      description = "Shared Kanidm OAuth2 context configurations.";
      default = { };
      type = attrsOf (submodule {
        options = commonKanidmOptions;
      });
    };

    server.proxy.virtualHosts = mkOption {
      type = attrsOf (
        submodule (
          { name, ... }: {
            options.kanidm = mkOption {
              default = null;
              description = "Enable Kanidm OAuth2 authentication for this virtual host.";
              type = nullOr (
                submodule (_: {
                  options = commonKanidmOptions // {
                    context = mkOption {
                      type = str;
                      default = builtins.head (lib.splitString ":" name);
                      description = "The OAuth context name for this virtual host.";
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
                  };
                })
              );
            };
          }
        )
      );
    };
  };

  config = {
    server.proxy.extensions.kanidm = {
      priority = 50;
      consumesExtraConfig = true;
      enable = mkDefault true;

      config =
        name: vh: _hostCfg:
        if vh.kanidm == null then
          ""
        else
          let
            sanitiseName = builtins.replaceStrings [ "-" "." ] [ "_" "_" ] name;
          in
          ''
            ${optionalString (vh.kanidm.bypassPaths != [ ]) ''
              @bypass_auth_${sanitiseName} path ${builtins.concatStringsSep " " vh.kanidm.bypassPaths}
              handle @bypass_auth_${sanitiseName} {
                ${vh._resolvedExtraConfig}
              }
            ''}
            route /auth/* {
              authenticate with ${name}_portal
            }
            handle {
              authorize with ${name}_policy
              ${vh._resolvedExtraConfig}
            }
          '';

      globalConfig =
        _hostCfg:
        let
          contexts = collectKanidmContexts;
          kanidmVirtualHosts = collectKanidmVirtualHosts;
        in
        optionalString (contexts != { }) ''
          ${optionalString hasAnyKanidm orderDirectives}
          security {
            ${generateIdentityProviders contexts}

            ${generateAuthenticationPortals kanidmVirtualHosts}

            ${generateAuthorizationPolicies kanidmVirtualHosts}
          }
        '';

      vhostModule = null;
    };

    sops.secrets =
      mkIf
        (config.services.kanidm.server.enable && config.services.kanidm.provision.enable && hasAnyKanidm)
        (
          builtins.listToAttrs (
            map (contextName: {
              name = "KANIDM/OAUTH2/${lib.toUpper contextName}_SECRET";
              value = {
                owner = "kanidm";
                group = "kanidm";
              };
            }) (builtins.attrNames kanidmContextsWithVirtualHosts)
          )
        );

    services.kanidm.provision.systems.oauth2 =
      mkIf
        (config.services.kanidm.server.enable && config.services.kanidm.provision.enable && hasAnyKanidm)
        (
          builtins.mapAttrs (contextName: ctx: {
            displayName = lib.mine.strings.capitalise (builtins.replaceStrings [ "-" ] [ " " ] contextName);
            originUrl = ctx.originUrls;
            originLanding = ctx.originLanding;
            basicSecretFile = config.sops.secrets."KANIDM/OAUTH2/${lib.toUpper contextName}_SECRET".path;
            scopeMaps = builtins.listToAttrs (
              map (group: {
                name = group;
                value = ctx.scopes;
              }) ctx.groups
            );
          }) kanidmContextsWithVirtualHosts
        );
  };
}
