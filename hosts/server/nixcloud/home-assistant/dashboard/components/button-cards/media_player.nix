{ lib, ... }:
with (import ../lib.nix { inherit lib; });
{
  type = "custom:button-card";
  template = "setup";
  variables = {
    room = entity.name;
    icon_1 = "";
    accent_color = "var(--green)";
  };
  show_entity_picture = true;
  show_name = true;
  show_state = true;
  name = "[[[ return (variables.room && variables.room.length > 0) ? variables.room : (entity.attributes.friendly_name || 'Player') ]]]";
  state = [
    {
      value = "playing";
      icon = "mdi:play-circle-outline";
    }
    {
      value = "paused";
      icon = "mdi:pause-circle-outline";
    }
  ];
  tap_action.action = "more-info";
  styles = {
    card = {
      border-radius = "12px";
      background-color = "var(--contrast2)";
      box-shadow = "none";
      padding = "12px";
    };
    icon.color = "var(--black)";
    name = {
      justify-self = "start";
      font-size = 14;
      font-weight = 600;
      color = "var(--contrast14)";
    };
    state = {
      justify-self = "start";
      font-size = 12;
      font-weight = 500;
      color = "var(--contrast20)";
    };
  };
}
