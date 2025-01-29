{ pkgs, ... }:
{
  programs.obs-studio = {
    enable = true;
    package = pkgs.obs-studio;
    plugins = with pkgs.obs-studio-plugins; [
      wlrobs
      # obs-vkcapture
      obs-pipewire-audio-capture
      # obs-backgroundremoval
      looking-glass-obs
      input-overlay
    ];
  };

  user.persistence =
    let
      dir = ".config/obs-studio";
    in
    {
      directories = [ "${dir}/basic" ];
      files = [ "${dir}/global.ini" ];
    };
}
