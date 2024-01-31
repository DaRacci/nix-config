{ ... }: {
  imports = [
    ./denaro.nix
    ./firefox.nix
    ./nextcloud.nix
    ./podman.nix
    ./secrets.nix
    ./theme.nix
  ];

  xdg.mimeApps.enable = true;
}
