{ pkgs, persistenceDirectory, ... }: {
  # TODO :: Ensure audio components are installed;
  home.packages = with pkgs.unstable; [ osu-lazer ];

  home.persistence."${persistenceDirectory}".directories = [
    ".local/share/osu"
  ];
}
