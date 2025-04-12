{
  pkgs,
  lib,
  ...
}:
{
  home.packages = with pkgs; [
    # Audio
    spotify
    decibels
    mousai

    # Image
    krita # Editor
    loupe # Viewer
    gnome-obfuscate

    # Video
    clapper # Player
    footage
    miru # Anime :)
    parabolic

    # Misc
    switcheroo # Converter
    # identity # Comparer (FIXME :: currently conflicts with mesa-demos?????)
  ];

  programs.mpv = {
    enable = true;
    scripts = with pkgs.mpvScripts; [
      youtube-upnext
      youtube-chat
      sponsorblock-minimal
      quality-menu
      reload

      webtorrent-mpv-hook
      vr-reversal
      visualizer
      videoclip
      thumbfast
      smartskip
      mpv-notify-send
      mpv-cheatsheet
      mpris
      modernz
      memo

      pkgs.mpvScripts.builtins.autocrop
    ];

    scriptOpts = {
      thumbfast.network = "yes";
    };

    # https://mpv.io/manual/stable
    config = {
      # Interface
      osc = false;
      osd-bar = false;
      osd-duration = 2000;

      # Watch Later
      save-position-on-quit = "yes";
      watch-later-options = "start, sid";

      title = "$${filename}";
      keep-open = "yes";

    };
  };

  xdg.mimeApps =
    let
      forAll =
        desktop: mimes:
        lib.mine.attrsets.recursiveMergeAttrs (builtins.map (mime: { ${mime} = desktop; }) mimes);
    in
    {
      # Krita and Switcheroo try to hijack a lot of file types
      defaultApplications =
        (forAll "org.gnome.Decibles.desktop" [
          "audio/aiff"
          "audio/flac"
          "audio/mp4"
          "audio/mpeg"
          "audio/ogg"
          "audio/opus"
          "audio/wav"
          "audio/webm"
        ])
        ++ (forAll "org.gnome.Loupe.desktop" [
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
        ]);
    };

  dconf.settings = with lib.hm.gvariant; {
    "net/nokyan/Resources" = {
      detailed-priority = true;
      graph-data-points = mkUint32 240;
      refresh-speed = "VeryFast";
      sidebar-description = true;
      sidebar-details = true;
      sidebar-meter-type = "Graph";
    };
  };

  user.persistence.directories = [
    ".config/spotify"
    ".config/Miru"

    ".local/share/spotube"
    ".local/share/oss.krtirtho.spotube"
    ".cache/oss.krtirtho.spotube/cached_tracks"
  ];
}
