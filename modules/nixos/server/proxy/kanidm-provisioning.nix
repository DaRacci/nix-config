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
    mkIf
    mkMerge
    unique
    flatten
    ;

  inherit (proxyLib) collectKanidmContexts collectKanidmVirtualHosts;

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
  config = mkMerge [
    (mkIf
      (
        config.services.kanidm.server.enable
        && config.services.kanidm.provision.enable
        && proxyLib.hasAnyKanidm
      )
      {
        sops.secrets = builtins.listToAttrs (
          map (contextName: {
            name = "KANIDM/OAUTH2/${lib.toUpper contextName}_SECRET";
            value = {
              owner = "kanidm";
              group = "kanidm";
            };
          }) (builtins.attrNames kanidmContextsWithVirtualHosts)
        );

        services.kanidm.provision.systems.oauth2 = builtins.mapAttrs (contextName: ctx: {
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
        }) kanidmContextsWithVirtualHosts;
      }
    )
  ];
}
