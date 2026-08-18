{
  imports = [
    ./books.nix
    ./downloader.nix
    ./indexer.nix
    ./movies.nix
    ./music.nix
    ./subs.nix
    ./tv.nix
  ];

  # This shit broken asf
  services.flaresolverr.enable = false;
  systemd.services.flaresolverr = {
    unitConfig = {
      StartLimitIntervalSec = "60m";
      StartLimitBurst = 5;
    };
    vpnConfinement = {
      enable = true;
      vpnNamespace = "wg";
    };
  };

  server.proxy.kanidmContexts = {
    arr-services = {
      allowGroups = [ "sysadmin@auth.racci.dev" ];
    };
  };
}
