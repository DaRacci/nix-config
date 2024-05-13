_: {
  imports = [
    ./caddy.nix
  ];

  services.getty.autologinUser = "root";
}
