{ pkgs, ... }:
{
  programs.alacritty = {
    enable = true;
    package = pkgs.alacritty;
    settings = {
      window = {
        decorations = "None";
        padding = {
          x = 0;
          y = 10;
        };
      };

      font = {
        builtin_box_drawing = true;
      };
    };
  };
}
