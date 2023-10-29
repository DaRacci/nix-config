# TODO -> Disko https://github.com/nix-community/disko
{
  services.btrfs.autoScrub = {
    enable = true;
    fileSystems = [ "/persist" ];
    interval = "monthly";
  };

  services.snapper.configs = {
    persist = {
      SUBVOLUME = "/persist";
      TIMELINE_CREATE = true;
      TIMELINE_CLEANUP = true;
    };
  };
}