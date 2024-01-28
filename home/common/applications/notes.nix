{ pkgs, ... }: {
  home.packages = with pkgs; [ obsidian rnote ];

  user.persistence.directories = [
    ".config/obsidian"
  ];
}
