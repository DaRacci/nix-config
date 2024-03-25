{ ... }: {
  imports = [
    ./denaro.nix
    ./nextcloud.nix
    ./podman.nix
    ./secrets.nix
  ];

  xdg.mimeApps.enable = true;
}
