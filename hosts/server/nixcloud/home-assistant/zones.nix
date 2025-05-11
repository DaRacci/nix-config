{
  services = {
    home-assistant.config = {
      homeassistant = {
        name = "Home - USA";
        latitude = "!secret home_usa_latitude";
        country = "USA";
        longitude = "!secret home_usa_longitude";
        elevation = "!secret home_usa_elevation";
        unit_system = "metric";
        temperature_unit = "C";
        time_zone = "America/Los_Angeles";
      };

      zone = [
        {
          name = "Home - Australia";
          icon = "mdi:human-male-female-child";
          latitude = "!secret home_aus_latitude";
          longitude = "!secret home_aus_longitude";
          radius = "200";
        }
      ];
    };
  };
}
