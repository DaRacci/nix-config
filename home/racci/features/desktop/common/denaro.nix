{ pkgs, ... }: {
  home.packages = with pkgs.unstable; [ denaro ];

  user.persistence.directories = [
    ".config/Nickvision/Nickvision Denaro"
  ];
}
