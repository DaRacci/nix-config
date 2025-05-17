{
  anyoneHasOption,
  ...
}:
{
  lib,
  ...
}:
{
  networking.firewall = lib.mkIf (anyoneHasOption (user: user.services.kdeconnect.enable)) rec {
    allowedTCPPortRanges = [
      {
        from = 1714;
        to = 1764;
      }
    ];
    allowedUDPPortRanges = allowedTCPPortRanges;
  };
}
