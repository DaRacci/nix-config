_: {
  imports = [
    ./power.nix
  ];

  custom.core = {
    audio.enable = true;
    bluetooth.enable = true;
  };
}
