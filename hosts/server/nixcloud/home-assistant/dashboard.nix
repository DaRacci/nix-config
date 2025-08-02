{

  pkgs,
  ...
}:
{
  services.home-assistant = {
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
      lovelace = {
        mode = "yaml";
        resources =
          [
            "Home-Assistant-Lovelace-Local-Conditional-card/local-conditional-card.js"
            "button-card/button-card.js"
            "config-template-card/config-template-card.js"
            "ha-floorplan/floorplan.js"
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
            url = "/hacsfiles/${resource}.";
          });
      };
    };
  };
}
