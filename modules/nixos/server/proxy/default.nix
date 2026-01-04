{
  isIOPrimaryHost,
  getIOPrimaryHostAttr,
  getAllAttrsFunc,
  collectAllAttrsFunc,
  importModule,
  ...
}:
{
  lib,
  ...
}:
let
  inherit (lib) toUpper;

  contextToEnvPrefix = context: builtins.replaceStrings [ "-" ] [ "_" ] (toUpper context);

  resolveKanidmContext =
    _name: vh:
    let
      domain = getIOPrimaryHostAttr "server.proxy.domain";
      sharedContexts = getIOPrimaryHostAttr "server.proxy.kanidmContexts";
      contextName = vh.kanidm.context;
      sharedContext = sharedContexts.${contextName} or null;
      baseContext =
        if sharedContext != null then
          {
            inherit (sharedContext) scopes tokenLifetime allowGroups;
            authDomain =
              if sharedContext.authDomain != null then sharedContext.authDomain else "auth.${domain}";
          }
        else
          {
            scopes = [
              "openid"
              "email"
              "profile"
              "groups"
            ];
            tokenLifetime = 3600;
            authDomain = "auth.${domain}";
            allowGroups = [ ];
          };
      mergedAllowGroups = lib.unique (baseContext.allowGroups ++ vh.kanidm.allowGroups);
    in
    {
      context = contextName;
      scopes = vh.kanidm.scopes or baseContext.scopes;
      tokenLifetime = vh.kanidm.tokenLifetime or baseContext.tokenLifetime;
      authDomain = if vh.kanidm.authDomain != null then vh.kanidm.authDomain else baseContext.authDomain;
      allowGroups = mergedAllowGroups;
      inherit (vh.kanidm) bypassPaths;
      inherit domain;
      cookieDomain = vh.baseUrl;
    };

  hasAnyKanidm =
    getAllAttrsFunc "server.proxy.virtualHosts" (
      virtualHosts: _: virtualHosts |> builtins.attrValues |> builtins.any (vh: vh.kanidm != null)
    )
    |> builtins.any (x: x);

  collectKanidmContexts =
    getAllAttrsFunc "server.proxy.virtualHosts" (
      virtualHosts: _:
      virtualHosts
      |> lib.filterAttrs (_: vh: vh.kanidm != null)
      |> lib.mapAttrsToList (name: vh: resolveKanidmContext name vh)
    )
    |> lib.flatten
    |> lib.foldl' (
      acc: ctx: if builtins.hasAttr ctx.context acc then acc else acc // { ${ctx.context} = ctx; }
    ) { };

  collectKanidmVirtualHosts = collectAllAttrsFunc "server.proxy.virtualHosts" (
    virtualHosts: _: virtualHosts |> lib.filterAttrs (_: vh: vh.kanidm != null)
  );

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

  proxyLib = {
    inherit
      contextToEnvPrefix
      resolveKanidmContext
      hasAnyKanidm
      collectKanidmContexts
      collectKanidmVirtualHosts
      replaceLocalHost
      ;
  };
in
{
  imports = [
    (importModule ./options.nix { inherit proxyLib; })
    (importModule ./kanidm.nix { inherit proxyLib; })
    (importModule ./config.nix { inherit proxyLib; })
    (importModule ./extensions.nix { inherit proxyLib; })
  ];
}
