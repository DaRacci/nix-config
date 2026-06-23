{
  isThisIOPrimaryHost,
  collectAllAttrsFunc,
  getAllAttrsFunc,
  ...
}:
{
  lib,
  ...
}:
let
  inherit (lib)
    mkDefault
    mkIf
    mkMerge
    nameValuePair
    ;
in
{
  config = mkMerge [
    {
      server.proxy.extensions.cloudflared = {
        priority = 200;
        enable = mkDefault (
          getAllAttrsFunc "server.proxy.virtualHosts" (
            vh: _: builtins.attrValues vh |> builtins.any (v: v.public)
          )
          |> builtins.any (x: x)
        );
        config =
          _name: _vh: _hostCfg:
          "";
        globalConfig = _hostCfg: "";
        vhostModule = null;
      };
    }

    (mkIf isThisIOPrimaryHost {
      services.cloudflared.tunnels."8d42e9b2-3814-45ea-bbb5-9056c8f017e2" =
        let
          publicHosts = collectAllAttrsFunc "server.proxy.virtualHosts" (
            vh: _:
            builtins.attrValues vh
            |> builtins.filter (v: v.public)
            |> map (v: nameValuePair v.baseUrl "https://${v.baseUrl}")
            |> builtins.listToAttrs
          );
        in
        mkIf ((builtins.attrValues publicHosts |> builtins.length) > 0) {
          ingress = publicHosts;
        };
    })
  ];
}
