{ pkgs, ... }: {
  home.packages = with pkgs; [ obsidian ];

  user.persistence.directories = [
    ".config/obsidian"
  ];
}
