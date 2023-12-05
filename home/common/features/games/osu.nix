{ pkgs, ... }: {
  # TODO :: Ensure audio components are installed;
  home.packages = with pkgs.unstable; [ osu-lazer ];

  user.persistence.directories = [
    ".local/share/osu"
  ];
}
