{ pkgs, lib, ... }: {
  home.packages = with pkgs; [
    loupe # Image viewer
    unstable.spotify
    delfin # Jellyfin client
    clapper # Video player
  ];

  xdg.mimeApps =
    let
      forAll = desktop: mimes: lib.mine.attrsets.recursiveMergeAttrs (builtins.map (mime: { ${mime} = desktop; }) mimes);
    in
    {
      defaultApplications = forAll "org.gnome.Loupe.Desktop" [
        "image/avif"
        "image/bmp"
        "image/gif"
        "image/heic"
        "image/vnd.microsoft.icon"
        "image/jpeg"
        "image/png"
        "image/svg+xml"
        "image/tiff"
        "image/webp"
      ];
    };

  user.persistence.directories = [
    ".config/spotify"
  ];
}
