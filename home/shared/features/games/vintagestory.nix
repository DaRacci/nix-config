{ pkgs, ... }: {
  home.packages = with pkgs.unstable; [ vintagestory ];

  user.persistence.directories = [
    ".config/VintagestoryData/"
  ];
}
