{
  basePath ? "/lovelace",
}:
{
  type = "custom:navbar-card";

  desktop = {
    position = "left";
    min_width = 768;
    show_labels = true;
  };

  mobile = {
    show_labels = true;
  };

  styles = ''
    .navbar {
      --navbar-primary-color: var(--purple-color);
      background: var(--contrast2);
    }
  '';

  routes = [
    {
      icon = "mdi:home-outline";
      icon_selected = "mdi:home-assistant";
      url = "${basePath}/home";
      label = "Home";
      selected = ''
        [[[
          if (location.hash == '#bedroom') return false;
          else if (location.hash == '#spare-room') return false;
          else if (location.hash == '#remote') return false;
          else if (location.hash == '#james') return false;
          else if (location.hash == '#savannah') return false;
          else return true;
        ]]]
      '';
    }
    {
      icon = "mdi:sofa-outline";
      icon_selected = "mdi:sofa";
      label = "Rooms";
      selected = ''
        [[[
          if (location.hash == '#bedroom') return true;
          else if (location.hash == '#spare-room') return true;
          else return false;
        ]]]
      '';
      badge.color = "var(--yellow-color)";
      tap_action.action = "open-popup";
      popup = [
        {
          icon = "mdi:bed-king-outline";
          url = "${basePath}/home#bedroom";
          label = "Bedroom";
        }
        {
          icon = "mdi:desk";
          url = "${basePath}/home#spare-room";
          label = "Spare Room";
        }
      ];
    }
    {
      icon = "mdi:music";
      url = "${basePath}/music";
      label = "Music";
      badge = {
        show = ''[[[ return states['media_player.music'].state === 'playing' ]]]'';
        color = "var(--green-color)";
      };
      hidden = ''
        [[[
          if (states['media_player.music'].state == "playing") return false;
          else return false;
        ]]]
      '';
      hold_action.action = "open-popup";
      popup = [
        {
          icon = "mdi:music";
          url = "${basePath}/music";
          label = "Music";
        }
        {
          icon = "mdi:television";
          url = "${basePath}/home#remote";
          label = "TV";
        }
      ];
    }
    {
      icon = "mdi:television";
      url = "${basePath}/home#remote";
      label = "TV";
      badge = {
        show = ''[[[ return states['media_player.apple_tv'].state === 'playing' ]]]'';
        color = "var(--green-color)";
      };
      hidden = ''
        [[[
          if (states['media_player.music'].state == "playing") return true;
          else if (states['remote.apple_tv'].state == "on") return false;
          else return true;
        ]]]
      '';
      selected = ''[[[ return location.hash == '#remote'; ]]]'';
      hold_action.action = "open-popup";
      popup = [
        {
          icon = "mdi:music";
          url = "${basePath}/music";
          label = "Music";
        }
        {
          icon = "mdi:television";
          url = "${basePath}/home#remote";
          label = "TV";
        }
      ];
    }
    {
      icon = "mdi:shield-outline";
      icon_selected = "mdi:security";
      url = "${basePath}/security";
      label = "Security";
      badge.color = "var(--red-color)";
    }
    {
      icon = "mdi:face-agent";
      url = "${basePath}/home#james";
      label = "James";
      selected = ''[[[ return location.hash == '#james'; ]]]'';
      hidden = ''[[[ return user.name != "James" ]]]'';
      badge = {
        show = ''[[[ return states['input_boolean.debug_rounded'].state === 'on' ]]]'';
        color = "var(--red-color)";
      };
    }
    {
      icon = "mdi:face-woman";
      url = "${basePath}/home#savannah";
      label = "Savannah";
      selected = ''[[[ return location.hash == '#savannah'; ]]]'';
      hidden = ''[[[ return user.name != "Savannah" ]]]'';
    }
    {
      icon = "mdi:dots-horizontal";
      label = "More";
      badge = {
        show = ''
          [[[
            if (states['binary_sensor.monitored_entities'].state == "on") return true;
            else if (states['binary_sensor.home_assistant_update'].state == "on") return true;
            else if (states['binary_sensor.battery_health_attention'].state == "on") return true;
            else return false;
          ]]]
        '';
        color = "var(--red-color)";
      };
      tap_action.action = "open-popup";
      popup = [
        {
          icon = "mdi:server-outline";
          url = "${basePath}/server";
          label = "Server";
          hidden = ''[[[ return user.name != "James" ]]]'';
          badge = {
            color = "var(--red-color)";
            show = ''
              [[[
                if (states['binary_sensor.monitored_entities'].state == "on") return true;
                else if (states['binary_sensor.battery_health_attention'].state == "on") return true;
                else return false;
              ]]]
            '';
          };
        }
        {
          icon = "mdi:cart";
          url = "${basePath}/home";
          label = "Shopping List";
          badge = {
            show = ''[[[ return states['todo.shopping_list'].state > 0 ]]]'';
            color = "var(--red-color)";
            count = ''[[[ return states['todo.shopping_list'].state ]]]'';
          };
        }
        {
          icon = "mdi:bookshelf";
          url = "/music-assistant";
          label = "Music Assistant";
        }
        {
          icon = "mdi:cog";
          url = "/config/dashboard";
          label = "Settings";
          badge.color = "var(--red-color)";
          hidden = ''[[[ return user.name != "James" ]]]'';
        }
        {
          icon = "mdi:hammer";
          url = "/developer-tools/yaml";
          label = "Developer Tools";
          hidden = ''[[[ return user.name != "James" ]]]'';
        }
      ];
    }
  ];
}
