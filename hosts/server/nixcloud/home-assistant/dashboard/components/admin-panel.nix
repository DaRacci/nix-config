{ lib }:
let
  dashLib = import ../lib.nix { inherit lib; };
  inherit (dashLib) entities ids;
in
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
          entity = entities.adguardProtection;
        }
        {
          type = "entity";
          entity = entities.adguardSpeed;
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
            entity = entities.sensors.uptimekuma;
            icon = "mdi:devices";
            name = "Monitored";
            label = "[[[return states[\"${entities.sensors.uptimekuma}\"].attributes.monitored]]]";
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
            entity = entities.sensors.uptimekuma;
            icon = "mdi:sort-clock-descending-outline";
            name = "Uptime Kuma";
            label = "[[[return states[\"${entities.sensors.uptimekuma}\"].attributes.monitors]]]";
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
        ids.james
        "c82f30a396fb42a9a10514fd63d5aac7"
      ];
    }
  ];
}
