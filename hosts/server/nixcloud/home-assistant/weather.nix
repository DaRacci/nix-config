{
  services.home-assistant = {
    extraComponents = [ "openweathermap" ];
    config = {
      conversation.intents = {
        WeatherToday = [
          "(What's|What is|How's|How is) the (weather|temperature) (like|outside) (today|right now|now|outside)"
          "(What's|What is|How's|How is) the (weather|temperature) (like|outside|right now|now|today)"
        ];
        WeatherTomorrow = [
          "(What's|What is|How's|How is) the (weather|temperature) (like|outside) (tomorrow|tomorrow morning|tomorrow afternoon|tomorrow evening)"
          "(What's|What is|How's|How is) the (weather|temperature) (tomorrow|tomorrow morning|tomorrow afternoon|tomorrow evening)"
        ];
      };

      intent_script = {
        WeatherToday.speech.text = ''
          The weather is currently {{ states('sensor.openweathermap_temperature') | round(0) }} degrees outside and {{ states('sensor.openweathermap_condition') }}.
        '';
        WeatherTomorrow.speech.text = ''
          Tomorrow will be {{ state_attr('weather.openweathermap', 'forecast')[1]["temperature"] | round(0) }} degrees and {{ state_attr('weather.openweathermap', 'forecast')[1]["condition"] }} with a low of {{ state_attr('weather.openweathermap', 'forecast')[1]["templow"] | round(0) }} degrees.
        '';
      };

      weather = { };
    };
  };
}
