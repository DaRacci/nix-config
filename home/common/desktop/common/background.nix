{ config, ... }: {
  services.random-background = {
    enable = true;
    display = "fill";

    imageDirectory = "/home/${config.home.username}/Pictures/Wallpapers";
    interval = "1h";
  };
}
