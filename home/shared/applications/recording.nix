{ pkgs, ... }:
let
  inherit (pkgs.obs-studio-plugins)
    input-overlay
    obs-pipewire-audio-capture
    obs-vkcapture
    wlrobs
    ;
  inherit (pkgs) handbrake;
in
{
  programs.obs-studio = {
    enable = true;
    package = pkgs.obs-studio;
    plugins = [
      wlrobs
      obs-vkcapture
      obs-pipewire-audio-capture
      # looking-glass-obs
      input-overlay
    ];
  };

  home.packages = [ handbrake ];

  user.persistence.directories = [
    ".config/obs-studio"
    ".config/ghb"
  ];
}
