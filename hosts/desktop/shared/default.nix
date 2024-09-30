{ flake, ... }: {
  imports = [
    "${flake}/hosts/shared/optional/stylix.nix"

    ./appimage.nix
    ./xdg.nix
  ];

  services.gvfs.enable = true;
}
