{ pkgs, persistencePath, ... }: {
  # TODO :: Ensure audio components are installed;
  home.packages = with pkgs.unstable; [ osu-lazer ];

  home.persistence."${persistencePath}".directories = [
    ".local/share/osu"
  ];
}
