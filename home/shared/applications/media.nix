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

    # Image
    gimp3 # Editor
    loupe # Viewer
    gnome-obfuscate

    # Video
    footage
    parabolic
    ff2mpv-rust
    tsukimi

    # Misc
    # switcheroo # Converter
    identity # Comparer
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
          "audio/3gpp"
          "audio/3gpp2"
          "audio/AMR"
          "audio/aac"
          "audio/ac3"
          "audio/aiff"
          "audio/amr-wb"
          "audio/dv"
          "audio/eac3"
          "audio/flac"
          "audio/m3u"
          "audio/m4a"
          "audio/mp1"
          "audio/mp2"
          "audio/mp3"
          "audio/mp4"
          "audio/mpeg"
          "audio/mpeg2"
          "audio/mpeg3"
          "audio/mpegurl"
          "audio/mpg"
          "audio/musepack"
          "audio/ogg"
          "audio/opus"
          "audio/rn-mpeg"
          "audio/scpls"
          "audio/vnd.dolby.heaac.1"
          "audio/vnd.dolby.heaac.2"
          "audio/vnd.dts"
          "audio/vnd.dts.hd"
          "audio/vnd.rn-realaudio"
          "audio/vnd.wave"
          "audio/vorbis"
          "audio/wav"
          "audio/webm"
          "audio/x-aac"
          "audio/x-adpcm"
          "audio/x-aiff"
          "audio/x-ape"
          "audio/x-m4a"
          "audio/x-matroska"
          "audio/x-mp1"
          "audio/x-mp2"
          "audio/x-mp3"
          "audio/x-mpegurl"
          "audio/x-mpg"
          "audio/x-ms-asf"
          "audio/x-ms-wma"
          "audio/x-musepack"
          "audio/x-pls"
          "audio/x-pn-au"
          "audio/x-pn-realaudio"
          "audio/x-pn-wav"
          "audio/x-pn-windows-pcm"
          "audio/x-realaudio"
          "audio/x-scpls"
          "audio/x-shorten"
          "audio/x-tta"
          "audio/x-vorbis"
          "audio/x-vorbis+ogg"
          "audio/x-wav"
          "audio/x-wavpack"
        ])
        // (forAll "org.gnome.Loupe.desktop" [
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
        ])
        // (forAll "mpv.desktop") [
          "application/mxf"
          "application/ogg"
          "application/sdp"
          "application/smil"
          "application/streamingmedia"
          "application/vnd.apple.mpegurl"
          "application/vnd.ms-asf"
          "application/vnd.rn-realmedia"
          "application/vnd.rn-realmedia-vbr"
          "application/x-cue"
          "application/x-extension-m4a"
          "application/x-extension-mp4"
          "application/x-matroska"
          "application/x-mpegurl"
          "application/x-ogg"
          "application/x-ogm"
          "application/x-ogm-audio"
          "application/x-ogm-video"
          "application/x-shorten"
          "application/x-smil"
          "application/x-streamingmedia"
          "video/3gp"
          "video/3gpp"
          "video/3gpp2"
          "video/avi"
          "video/divx"
          "video/dv"
          "video/fli"
          "video/flv"
          "video/mkv"
          "video/mp2t"
          "video/mp4"
          "video/mp4v-es"
          "video/mpeg"
          "video/msvideo"
          "video/ogg"
          "video/quicktime"
          "video/vnd.avi"
          "video/vnd.divx"
          "video/vnd.mpegurl"
          "video/vnd.rn-realvideo"
          "video/webm"
          "video/x-avi"
          "video/x-flc"
          "video/x-flic"
          "video/x-flv"
          "video/x-m4v"
          "video/x-matroska"
          "video/x-mpeg2"
          "video/x-mpeg3"
          "video/x-ms-afs"
          "video/x-ms-asf"
          "video/x-ms-wmv"
          "video/x-ms-wmx"
          "video/x-ms-wvxvideo"
          "video/x-msvideo"
          "video/x-ogm"
          "video/x-ogm+ogg"
          "video/x-theora"
          "video/x-theora+ogg"
        ];
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
  ];
}
