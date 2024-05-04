_: {
  imports = [
    ./power.nix
    ../../desktop/shared/appimage.nix
  ];

  custom.core = {
    audio.enable = true;
    bluetooth.enable = true;
  };
}
