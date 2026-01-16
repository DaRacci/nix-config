{
  isThisIOPrimaryHost,
  proxyLib,
  ...
}:
{
  lib,
  ...
}:
let
  inherit (lib)
    mkIf
    optionalString
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
    |> builtins.map (
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
    |> builtins.map (
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
    |> builtins.map (
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
            resolved.allowGroups
            |> builtins.map (group: "allow groups ${group}")
            |> builtins.concatStringsSep "\n    "
          }
        }
      ''
    )
    |> builtins.concatStringsSep "\n";

  generateSecurityBlock =
    let
      contexts = collectKanidmContexts;
      kanidmVirtualHosts = collectKanidmVirtualHosts;
    in
    optionalString (contexts != { }) ''
      security {
        ${generateIdentityProviders contexts}

        ${generateAuthenticationPortals kanidmVirtualHosts}

        ${generateAuthorizationPolicies kanidmVirtualHosts}
      }
    '';
in
{
  config = mkIf isThisIOPrimaryHost {
    services.caddy.globalConfig = ''
      ${optionalString hasAnyKanidm orderDirectives}

      ${generateSecurityBlock}
    '';
  };
}
