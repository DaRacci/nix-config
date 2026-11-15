{
  proxyLib,
  isThisIOPrimaryHost,
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
    bool
    nullOr
    path
    listOf
    attrsOf
    submodule
    ;

  inherit (proxyLib)
    contextToEnvPrefix
    sanitiseName
    portalName
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
          delay_start 10
          retry_attempts 12
          retry_interval 5
          scopes ${builtins.concatStringsSep " " ctx.scopes}
        }
      ''
    )
    |> builtins.concatStringsSep "\n";

  generateAuthenticationPortals =
    kanidmVirtualHosts:
    let
      portals =
        kanidmVirtualHosts
        |> builtins.attrNames
        |> map (
          name:
          let
            vh = kanidmVirtualHosts.${name};
            resolved = resolveKanidmContext name vh;
          in
          {
            portal = portalName name resolved;
            inherit resolved;
          }
        )
        |> lib.foldl' (
          acc: entry: if builtins.hasAttr entry.portal acc then acc else acc // { ${entry.portal} = entry; }
        ) { };
    in
    portals
    |> builtins.attrValues
    |> map (
      { portal, resolved }:
      ''
        authentication portal ${portal} {
          crypto default token lifetime ${toString resolved.tokenLifetime}
          cookie domain "${resolved.cookieDomain}"
          ${optionalString (resolved.cookiePrefix != null) ''
            set cookie name prefix ${resolved.cookiePrefix}
          ''}
          crypto key sign-verify {env.${contextToEnvPrefix resolved.context}_SHARED_KEY}
          enable identity provider ${resolved.context}
          ui {
            theme basic
            ${optionalString (config.server.proxy.kanidmPortalCss != null) ''
              custom css path ${config.server.proxy.kanidmPortalCss}
            ''}
          }
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
          set auth url https://${vh.baseUrl}/auth/oauth2/${resolved.context}
          crypto key sign-verify {env.${envPrefix}_SHARED_KEY}
          ${optionalString (resolved.cookiePrefix != null) ''
            set session_id cookie name ${resolved.cookiePrefix}_SESSION_ID
            set access_token cookie name ${resolved.cookiePrefix}_ACCESS_TOKEN
          ''}
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
        Defaults to auth.<data.site.domain> if not specified.
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

  contextOnlyOptions = {
    sharedPortal = mkOption {
      type = bool;
      default = false;
      description = ''
        Serve one authentication portal for every virtual host using this context.
        A single portal means a single session, so a login on one host is valid on the others once they share `cookieDomain`.
      '';
    };

    cookieDomain = mkOption {
      type = nullOr str;
      default = null;
      example = "example.com";
      description = ''
        Cookie domain for the portal session cookies.
        When set, the cookie is shared by every host under this domain,
        which is what makes authentication carry across those hosts.
        A leading dot is accepted and stripped by the plugin.
      '';
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
        # `ctx.allowGroups` is already resolved against the context definition,
        # so this covers context-level and per-virtual-host groups alike.
        # Every allowed group needs a scope map, otherwise Kanidm denies the login.
        allGroups = unique (ctx.allowGroups ++ (vhList |> map (vh: vh.kanidm.allowGroups) |> flatten));
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
    ) contexts
    |> lib.filterAttrs (_: ctx: builtins.length (builtins.attrValues ctx.virtualHosts) > 0);

  allKanidmVirtualHosts = collectKanidmVirtualHosts;

  portalContexts =
    allKanidmVirtualHosts
    |> builtins.attrNames
    |> map (
      name:
      let
        resolved = resolveKanidmContext name allKanidmVirtualHosts.${name};
      in
      {
        portal = portalName name resolved;
        context = resolved.context;
      }
    )
    |> lib.foldl' (
      acc: entry: acc // { ${entry.portal} = (acc.${entry.portal} or [ ]) ++ [ entry.context ]; }
    ) { };

  portalsWithMixedContexts = lib.filterAttrs (
    _: contexts: builtins.length (unique contexts) > 1
  ) portalContexts;

  contextsMissingCookieDomain = lib.filterAttrs (
    _: ctx: ctx.sharedPortal && ctx.cookieDomain == null
  ) config.server.proxy.kanidmContexts;

  contextsWithoutGroups = lib.filterAttrs (_: ctx: ctx.groups == [ ]) kanidmContextsWithVirtualHosts;
in
{
  options = {
    server.proxy.kanidmPortalCss = mkOption {
      type = nullOr path;
      default = ../portal.css;
      description = ''
        Stylesheet applied to every Kanidm authentication portal.
        Defaults to the dark theme shipped with this module.
        Set to null to use the plugin's own styling.
      '';
    };

    server.proxy.kanidmContexts = mkOption {
      description = "Shared Kanidm OAuth2 context configurations.";
      default = { };
      type = attrsOf (submodule {
        options = commonKanidmOptions // contextOnlyOptions;
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
                      description = "List of path patterns that never require authentication.";
                    };

                    protectedPaths = mkOption {
                      type = listOf str;
                      default = [ ];
                      example = [ "/ui/*" ];
                      description = ''
                        Path patterns that require authentication.
                        When empty, the whole host requires authentication.
                        When set, only matching paths do and every other path is served
                        without authentication, which keeps machine endpoints reachable.
                        `bypassPaths` still takes precedence for the paths it lists.
                      '';
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
    assertions = [
      {
        assertion = contextsMissingCookieDomain == { };
        message = "server.proxy.kanidmContexts.<name>.sharedPortal requires cookieDomain, otherwise the shared portal cannot carry a session across hosts.";
      }
      {
        assertion = portalsWithMixedContexts == { };
        message = "Duplicate Kanidm portal name across contexts. A shared portal is named after its context, so no virtual host may be named after that context.";
      }
      {
        assertion = contextsWithoutGroups == { };
        message = "A Kanidm context must resolve at least one group through `allowGroups` (on the context or on the virtual host). Kanidm only issues a token to groups listed in the OAuth2 client scope map, so an empty list makes every login fail with Access Denied.";
      }
    ];

    server.proxy.extensions.kanidm = {
      priority = 50;
      consumesExtraConfig = true;
      enable = mkDefault hasAnyKanidm;

      config =
        name: vh: _hostCfg:
        if vh.kanidm == null then
          ""
        else
          let
            resolved = resolveKanidmContext name vh;
            portal = portalName name resolved;
            matcherName = sanitiseName name;
            extra = vh._resolvedExtraConfig;
            protectedPaths = vh.kanidm.protectedPaths;
          in
          ''
            ${optionalString (vh.kanidm.bypassPaths != [ ]) ''
              @bypass_auth_${matcherName} path ${builtins.concatStringsSep " " vh.kanidm.bypassPaths}
              handle @bypass_auth_${matcherName} {
                ${extra}
              }
            ''}
            @auth_path_${matcherName} path /auth /auth/*
            handle @auth_path_${matcherName} {
              authenticate with ${portal} at /auth
            }
            ${optionalString (protectedPaths != [ ]) ''
              @protect_auth_${matcherName} path ${builtins.concatStringsSep " " protectedPaths}
              handle @protect_auth_${matcherName} {
                authorize with ${name}_policy
                ${extra}
              }
              handle {
                ${extra}
              }
            ''}
            ${optionalString (protectedPaths == [ ]) ''
              handle {
                authorize with ${name}_policy
                ${extra}
              }
            ''}
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

    sops.secrets = lib.mkMerge [
      (mkIf (isThisIOPrimaryHost && hasAnyKanidm) (
        builtins.listToAttrs (
          lib.concatMap (
            contextName:
            let
              upperContext = lib.toUpper contextName;
              value = {
                owner = "caddy";
                group = "caddy";
                mode = "0400";
                restartUnits = [ "caddy.service" ];
              };
            in
            [
              {
                name = "KANIDM/OAUTH2/${upperContext}_SECRET";
                inherit value;
              }
              {
                name = "PROXY_AUTH/KANIDM/${upperContext}_SHARED_KEY";
                inherit value;
              }
            ]
          ) (builtins.attrNames kanidmContextsWithVirtualHosts)
        )
      ))

      (mkIf
        (config.services.kanidm.server.enable && config.services.kanidm.provision.enable && hasAnyKanidm)
        (
          builtins.listToAttrs (
            map (contextName: {
              name = "KANIDM/OAUTH2/${lib.toUpper contextName}_SECRET";
              value = {
                owner = "kanidm";
                group = "kanidm";
                mode = "0400";
                restartUnits = [ "kanidm.service" ];
              };
            }) (builtins.attrNames kanidmContextsWithVirtualHosts)
          )
        )
      )
    ];

    sops.templates = mkIf (isThisIOPrimaryHost && hasAnyKanidm) (
      builtins.listToAttrs (
        map (
          contextName:
          let
            upperContext = lib.toUpper contextName;
          in
          {
            name = "PROXY_AUTH/KANIDM/${upperContext}_ENV";
            value = {
              owner = "caddy";
              group = "caddy";
              mode = "0400";
              content = ''
                OAUTH_${upperContext}_CLIENT_SECRET=${
                  config.sops.placeholder."KANIDM/OAUTH2/${upperContext}_SECRET"
                }
                ${upperContext}_SHARED_KEY=${config.sops.placeholder."PROXY_AUTH/KANIDM/${upperContext}_SHARED_KEY"}
              '';
            };
          }
        ) (builtins.attrNames kanidmContextsWithVirtualHosts)
      )
    );

    systemd.services.caddy.serviceConfig.EnvironmentFile = mkIf (isThisIOPrimaryHost && hasAnyKanidm) (
      map (contextName: config.sops.templates."PROXY_AUTH/KANIDM/${lib.toUpper contextName}_ENV".path) (
        builtins.attrNames kanidmContextsWithVirtualHosts
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
