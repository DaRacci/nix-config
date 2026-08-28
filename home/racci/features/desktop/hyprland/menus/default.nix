{
  imports = [
    ./popups.nix
    ./vicinae.nix
  ];

  programs.noctalia.settings = {
    calendar.account.home_nextcloud = {
      name = "Personal";
      provider = "custom";
      server_url = "https://nextcloud.racci.dev/remote.php/dav/calendars/Racci/personal/";
      type = "caldav";
      username = "Racci";
    };

    bar = {
      default.monitor = {
        DP-6.enabled = true;
        DP-1.enabled = false;
        HDMI-A-1.enabled = false;
      };

      side_bar.monitor = {
        DP-1 = {
          enabled = true;
          position = "right";
          concave_edge_corners = true;
          radius_bottom_left = 12;
          radius_bottom_right = 0;
          radius_top_left = 12;
          radius_top_right = 0;
        };

        HDMI-A-1 = {
          enabled = true;
          position = "left";
          concave_edge_corners = true;
          radius_bottom_left = 0;
          radius_bottom_right = 12;
          radius_top_left = 0;
          radius_top_right = 12;
        };
      };
    };
  };
}
