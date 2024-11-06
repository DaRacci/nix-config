_: {
  programs.cava = {
    enable = true;
    settings = {
      general = {
        mode = "scientific";
        framerate = 240;
        autosense = 1;
        sensitivity = 100;

        bars = 0;
        bar_width = 1;
        bar_spacing = 1;
        bar_height = 24;
      };

      input = {
        method = "pipewire";
        source = "auto";
      };

      output = { };

      color = {
        background = "default";
        foreground = "cyan";

        gradient = 1;
        gradient_count = 4;
        gradient_color_1 = "'#0BA6A8'";
        gradient_color_2 = "'#84B6CC'";
        gradient_color_3 = "'#84B6CC'";
        gradient_color_4 = "'#3B307C'";
      };

      smoothing = { };
    };
  };
}
