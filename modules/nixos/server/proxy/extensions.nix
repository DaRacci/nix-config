{
  isThisIOPrimaryHost,
  collectAllAttrsFunc,
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
    mkDefault
    mkIf
    mkMerge
    nameValuePair
    unique
    flatten
    ;

  cfg = config.server.proxy;

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
        allGroups = vhList |> builtins.map (vh: vh.kanidm.allowGroups) |> flatten |> unique;
        groupsWithoutDomain = allGroups |> builtins.map (g: builtins.head (lib.splitString "@" g));
      in
      ctx
      // {
        virtualHosts = vhsUsingContext;
        originUrls = builtins.map (
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
    {
      server.dashboard.items = builtins.mapAttrs (_name: vhCfg: {
        title = mkDefault (lib.mine.strings.capitalise _name);
        url = mkDefault "https://${vhCfg.baseUrl}/";
        icon = mkDefault "sh-${_name}";
      }) cfg.virtualHosts;
    }

    (mkIf isThisIOPrimaryHost {
      services.cloudflared.tunnels."8d42e9b2-3814-45ea-bbb5-9056c8f017e2" =
        let
          publicHosts = collectAllAttrsFunc "server.proxy.virtualHosts" (
            vh: _:
            builtins.attrValues vh
            |> builtins.filter (v: v.public)
            |> builtins.map (v: nameValuePair v.baseUrl "https://${v.baseUrl}")
            |> builtins.listToAttrs
          );
        in
        mkIf ((builtins.attrValues publicHosts |> builtins.length) > 0) {
          ingress = publicHosts;
        };
    })

    (mkIf
      (
        config.services.kanidm.enableServer
        && config.services.kanidm.provision.enable
        && proxyLib.hasAnyKanidm
      )
      {
        sops.secrets = builtins.listToAttrs (
          builtins.map (contextName: {
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
            builtins.map (group: {
              name = group;
              value = ctx.scopes;
            }) ctx.groups
          );
        }) kanidmContextsWithVirtualHosts;
      }
    )
  ];
}
