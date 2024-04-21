{ flake, pkgs, ... }:
let inherit (pkgs) lib; in {
  imports = [
    "${flake}/home/shared/desktop/common"
    "${flake}/home/shared/desktop/wayland"
    "${flake}/home/shared/desktop/x11"

    ./dconf-base.nix
    ./dconf-extensions.nix
  ];

  home.packages = with pkgs; [
    glib
    gnome-decoder
    eyedropper
    raider
  ];

  user.persistence.directories = [
    # Online Accounts
    ".config/goa-1.0"

    # Online Accounts - Email
    ".local/share/gnome-control-center-goa-helper"
    ".local/share/geary"
    ".config/geary"

    # Online Accounts - Calendar
    ".config/evolution"

    # Gnome Extensions and settings
    ".cache/clipboard-indicator@tudmotu.com" # Clipboard history
    ".config/gsconnect" # Gsconnect
  ];

  xdg.mimeApps =
    let
      forAll = desktop: mimes: lib.mine.attrsets.recursiveMergeAttrs (builtins.map (mime: { ${mime} = desktop; }) mimes);
    in
    {
      enable = true;

      associations.added = forAll "org.gnome.shell.Extensions.GSConnect.desktop" [
        "x-scheme-handler/sms"
        "x-scheme-handler/tel"
      ];

      defaultApplications = forAll "org.gnome.Loupe.Desktop" [
        "image/jpeg"
        "image/png"
      ];
    };
}
