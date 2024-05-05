_: {

  # Fixes not being able to open applications using xdg-open
  # Fix taken from https://github.com/NixOS/nixpkgs/issues/189851#issuecomment-1238907955
  # Then improved upon by https://github.com/NixOS/nixpkgs/issues/189851#issuecomment-1759954096
  systemd.user.extraConfig = ''
    DefaultEnvironment="PATH=/run/wrappers/bin:/etc/profiles/per-user/%u/bin:/nix/var/nix/profiles/default/bin:/run/current-system/sw/bin"
  '';
}
