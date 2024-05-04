{ pkgs, ... }: {
  home.sessionVariables = {
    NIX_LD_LIBRARY_PATH = with pkgs; lib.makeLibraryPath [
      stdenv.cc.cc
      glibc
      glib
      libelf
      nss
      nspr
      dbus
    ];

    NIX_LD = builtins.readFile "${pkgs.stdenv.cc}/nix-support/dynamic-linker";
  };
}
