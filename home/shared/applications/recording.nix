{ pkgs, ... }:
{
  programs.obs-studio = {
    enable = true;
    package = pkgs.obs-studio;
    plugins = with pkgs.obs-studio-plugins; [
      wlrobs
      obs-vkcapture
      obs-pipewire-audio-capture
      looking-glass-obs
      input-overlay
    ];
  };

  user.persistence.directories = [ ".config/obs-studio" ];
}
