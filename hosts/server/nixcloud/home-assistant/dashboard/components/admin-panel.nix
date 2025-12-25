{
  type = "vertical-stack";
  cards = [
    {
      type = "heading";
      heading = "Admin";
      heading_style = "title";
      icon = "mdi:account";
      tap_action = {
        action = "navigate";
        navigation_path = "/lovelace/server";
      };
      badges = [
        {
          type = "entity";
          entity = "switch.adguard_home_protection";
        }
        {
          type = "entity";
          entity = "sensor.adguard_home_average_processing_speed";
        }
      ];
    }
    {
      square = false;
      type = "grid";
      cards = [
        {
          type = "conditional";
          conditions = [ ];
          card = {
            type = "custom:button-card";
            entity = "sensor.uptimekuma_uptime_racci_dev";
            icon = "mdi:devices";
            name = "Monitored";
            label = "[[[return states[\"sensor.uptimekuma_uptime_racci_dev\"].attributes.monitored]]]";
            template = "nav_button_state_small";
            variables = {
              navigation_path = "server#monitored";
              icon_on = "mdi:devices";
              icon_off = "mdi:devices";
              background_color_on = "var(--red)";
              background_color_off = "var(--green)";
            };
          };
        }
        {
          type = "conditional";
          conditions = [ ];
          card = {
            type = "custom:button-card";
            entity = "sensor.uptimekuma_uptime_racci_dev";
            icon = "mdi:sort-clock-descending-outline";
            name = "Uptime Kuma";
            label = "[[[return states[\"sensor.uptimekuma_uptime_racci_dev\"].attributes.monitors]]]";
            template = "nav_button_small";
            variables = {
              navigation_path = "#uptime";
              icon_on = "mdi:sort-clock-descending-outline";
              icon_off = "mdi:sort-clock-descending-outline";
              background_color_on = "var(--purple)";
              background_color_off = "var(--red)";
            };
          };
        }
      ];
      columns = 2;
    }
  ];
  visibility = [
    {
      condition = "user";
      users = [
        "3eea636aa3de4c7f9c662ad29c6e92e0"
        "c82f30a396fb42a9a10514fd63d5aac7"
      ];
    }
  ];
}
