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
  systemd.services.flaresolverr.vpnConfinement = {
    enable = true;
    vpnNamespace = "wg";
  };
}
