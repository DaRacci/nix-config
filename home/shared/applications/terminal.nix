{ pkgs, ... }:
{
  programs.alacritty = {
    enable = true;
    package = pkgs.alacritty;
    settings = {
      terminal.shell = {

      };

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
