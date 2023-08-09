{ pkgs, ... }: {
  imports = [
    ./lutris.nix
    ./mangohud.nix
    ./modding.nix
    ./osu.nix
    ./steam.nix
    ./vintagestory.nix
    ./wine.nix
  ];

  # home.packages = with pkgs; [ dualsensectl ];
}
