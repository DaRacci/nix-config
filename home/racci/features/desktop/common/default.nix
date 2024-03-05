{ ... }: {
  imports = [
    ./denaro.nix
    ./nextcloud.nix
    ./podman.nix
    ./secrets.nix
    ./theme.nix
  ];

  xdg.mimeApps.enable = true;
}
