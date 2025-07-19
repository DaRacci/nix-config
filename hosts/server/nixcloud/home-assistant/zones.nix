{
  services = {
    home-assistant.config = {
      homeassistant = {
        name = "Home - Australia";
        latitude = "!secret home_aus_latitude";
        country = "AU";
        longitude = "!secret home_aus_longitude";
        elevation = "!secret home_aus_elevation";
        unit_system = "metric";
        temperature_unit = "C";
        time_zone = "Australia/Sydney";
      };

      zone = [
        {
          name = "Home - USA";
          icon = "mdi:human-male-female-child";
          latitude = "!secret home_usa_latitude";
          longitude = "!secret home_usa_longitude";
          radius = "200";
        }
      ];
    };
  };
}
