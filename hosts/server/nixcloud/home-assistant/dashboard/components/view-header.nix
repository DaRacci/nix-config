{
  content ? ''
    {% if (states("sensor.time_of_day") == "morning") %}
      # Good Morning, {{user}}!
      {{ states("input_text.ai_morning_brief") }}
    {% elif (states("sensor.time_of_day") == "day") %}
      # Hey, {{user}}!
      It's {{ states("sensor.time") }}, the weather is {{ state_translated("weather.home") | lower }} with {{ state_attr("weather.home","temperature") }}°C. Right now there are {{ states("sensor.lights_on_count") }} lights on and {{ states("sensor.window_open_count") }} windows open. The security system is set to {{ state_translated("alarm_control_panel.security_system") }}; the flat door is {{ states("lock.flat_door") }}.
    {% elif (states("sensor.time_of_day") == "evening") %}
      # Good Evening, {{user}}!
      It's {{ states("sensor.time") }}, the weather is {{ state_translated("weather.home") | lower }} with {{ state_attr("weather.home","temperature") }}°C. Right now there are {{ states("sensor.lights_on_count") }} lights on and {{ states("sensor.window_open_count") }} windows open. The security system is set to {{ state_translated("alarm_control_panel.security_system") }}; the flat door is {{ states("lock.flat_door") }}. {% if states("binary_sensor.is_alarm_on") == "on" %}Your alarm is set to {{ states("sensor.wake_time_1") }}.{% endif %}

    {% elif (states("sensor.time_of_day") == "night") %}
      # Good Night, {{user}}!
      It's {{ states("sensor.time") }}, the weather is {{ state_translated("weather.home") | lower }} with {{ state_attr("weather.home","temperature") }}°C. Right now there are {{ states("sensor.lights_on_count") }} lights on and {{ states("sensor.window_open_count") }} windows open. The security system is set to {{ state_translated("alarm_control_panel.security_system") }}; the flat door is {{ states("lock.flat_door") }}. {% if states("binary_sensor.is_alarm_on") == "on" %}Your alarm is set to {{ states("sensor.wake_time_1") }}.{% endif %}

    {% endif %}
  '',
  media_query ? "(min-width: 768px)",
  text_only ? true,
  layout ? "responsive",
  badges_position ? "top",
  badges_wrap ? "scroll",
  cardOverrides ? { },
}:
{
  card = {
    type = "markdown";
    inherit text_only;
    inherit content;
    visibility = [
      {
        condition = "screen";
        inherit media_query;
      }
    ];
  }
  // cardOverrides;

  inherit layout;
  inherit badges_position;
  inherit badges_wrap;
}
