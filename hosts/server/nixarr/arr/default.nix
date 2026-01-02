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

  services.flaresolverr.enable = true;
  systemd.services.flaresolverr = {
    serviceConfig = {
      StartLimitIntervalSec = "60m";
      StartLimitBurst = 5;
    };
    vpnConfinement = {
      enable = true;
      vpnNamespace = "wg";
    };
  };
}
