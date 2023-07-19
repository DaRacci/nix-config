{ ... }: {
  services.random-background = {
    enable = true;
    display = "fill";

    imageDirectory = "/home/racci/Pictures/Wallpapers";
    interval = "1h";
  };
}
