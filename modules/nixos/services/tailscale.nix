{
  config,
  lib,
  ...
}:
let
  cfg = config.services.tailscale;
in
{
  options.services.tailscale = with lib.types; {
    tags = lib.mkOption {
      type = listOf str;
      default = [ ];
      description = ''
        Additional tags to advertise for this device.

        Tags are used for access control and routing in Tailscale.
        See https://tailscale.com/kb/1018/tags/ for more information.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.tailscale.extraUpFlags = lib.optional (lib.length cfg.tags > 0) (
      cfg.tags
      |> builtins.map (t: "tag:${t}")
      |> builtins.concatStringsSep ","
      |> (tags: "--advertise-tags=${tags}")
    );
  };
}
