{
  pkgs,
  ...
}:
{
  services.home-assistant = rec {
    customLovelaceModules = with pkgs.home-assistant-custom-lovelace-modules; [
      auto-entities
      bubble-card
      card-mod
      clock-weather-card
      decluttering-card
      hourly-weather
      mini-graph-card
      mini-media-player
      mushroom
      plotly-chart-card
      universal-remote-card
      vacuum-card
      versatile-thermostat-ui-card
      weather-chart-card
    ];

    config = {
      frontend = {
        themes = "!include_dir_merge_named themes/";
      };

      template = [
        {
          trigger = [
            {
              trigger = "event";
              event_type = "bubble_card_update_modules";
            }
          ];
          sensor = [
            {
              name = "Bubble Card Modules";
              state = "saved";
              icon = "mdi:puzzle";
              attributes = {
                modules = "{{ trigger.event.data.modules }}";
                last_updated = "{{ trigger.event.data.last_updated }}";
              };
            }
          ];
        }
      ];

      sensor = [
        {
          platform = "template";
          sensors = {
            lights_on_count = {
              unique_id = "lightsoncount";
              friendly_name = "Lights on count";
              value_template = ''
                {% set lights_on = states.light
                  | selectattr("state", "eq", "on")
                  | list
                  | count %}
                {{ lights_on }}
              '';
            };
            window_open_count = {
              unique_id = "windowopencount";
              friendly_name = "Window open count";
              value_template = ''
                {% set windows_on = states.binary_sensor
                  | selectattr("attributes.device_class", "eq", "window")
                  | selectattr("state", "eq", "on")
                  | list
                  | count %}
                {{ windows_on }}
              '';
            };
          };
        }
      ];

      lovelace = {
        mode = "yaml";
        resources = [
          {
            url = "/local/nixos-lovelace-modules/bubble-pop-up-fix.js";
            type = "module";
          }
        ]
        ++ (
          # These are installed via HACS normally, but we need to include them here to actually activate them.
          [
            "button-card/button-card.js"
            "config-template-card/config-template-card.js"
            "custom-brand-icons/custom-brand-icons.js"
            "ha-floorplan/floorplan.js"
            "hass-selfhst-icons/hass-selfhst-icons.js"
            "Home-Assistant-Lovelace-Local-Conditional-card/local-conditional-card.js"
            "lovelace-hass-arlo/hass-arlo.js"
            "lovelace-layout-card/layout-card.js"
            "lovelace-navbar-card/navbar-card.js"
            "my-cards/my-cards.js"
            "stack-in-card/stack-in-card.js"
            "swipe-card/swipe-card.js"
            "vertical-stack-in-card/vertical-stack-in-card.js"
            "weather-card/weather-card.js"
          ]
          |> builtins.map (resource: {
            type = "module";
            url = "/local/community/${resource}";
          })
        )
        ++ (builtins.map (card: {
          url = "/local/nixos-lovelace-modules/${card.entrypoint or (card.pname + ".js")}?${card.version}";
          type = "module";
        }) customLovelaceModules);
      };
    };
  };
}
