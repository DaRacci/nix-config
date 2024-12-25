{ pkgs, ... }: {
  imports = [
    ./nextcloud.nix
    ./secrets.nix
    ./zed.nix
  ];

  xdg.mimeApps.enable = true;

  home.packages = [
    pkgs.miru
  ];

  user.persistence.directories = [
    ".config/Miru"
  ];
}
