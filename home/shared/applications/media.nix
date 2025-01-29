{ pkgs, lib, ... }:
{
  home.packages = with pkgs; [
    loupe # Image viewer
    spotify
    delfin # Jellyfin client
    clapper # Video player
    switcheroo # Converter Utility
  ];

  xdg.mimeApps =
    let
      forAll =
        desktop: mimes:
        lib.mine.attrsets.recursiveMergeAttrs (builtins.map (mime: { ${mime} = desktop; }) mimes);
    in
    {
      # Krita and Switcheroo try to highjack all image files.
      defaultApplications = forAll "org.gnome.Loupe.desktop" [
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

  user.persistence.directories = [ ".config/spotify" ];
}
