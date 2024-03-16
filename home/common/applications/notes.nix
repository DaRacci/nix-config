{ pkgs, ... }: {
  home.packages = with pkgs; [ unstable.obsidian ];

  user.persistence.directories = [
    ".config/obsidian"
  ];
}
