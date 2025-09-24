{ lib, ... }:
with (import ../lib.nix { inherit lib; });
let
  viewHeader = import ../components/view-header.nix {
    content = ''
      # Security
    '';
  };

  navbar = import ../components/navbar.nix { };
in
mkView {
  title = "Security";
  header = viewHeader;
  path = "security";
  icon = "mdi:security";

  badges = [ ];

  sections = [
    (mkGridSection {
      cards = [ navbar ];
      grid_options = {
        columns = "full";
        rows = "auto";
      };
    })
    (mkGridSection {
      cards = [
        (mkHeading {
          heading = "Status";
          icon = "mdi:shield";
        })
        {
          type = "entities";
          entities = [
            "alarm_control_panel.security_system"
            "lock.flat_door"
            "sensor.window_open_count"
          ];
        }
      ];
      grid_options = {
        columns = "full";
        rows = "auto";
      };
    })
    (mkGridSection {
      cards = [
        (mkHeading {
          heading = "Alarm";
          icon = "mdi:alarm-light";
        })
        {
          type = "alarm-panel";
          entity = "alarm_control_panel.security_system";
          states = [
            "arm_home"
            "arm_away"
            "arm_night"
          ];
        }
      ];
      grid_options = {
        columns = "full";
        rows = "auto";
      };
    })
    (mkGridSection {
      cards = [
        (mkHeading {
          heading = "Locks";
          icon = "mdi:lock";
        })
        {
          type = "custom:auto-entities";
          card.type = "entities";
          filter = {
            exclude = [ ];
            include = [
              { domain = "lock"; }
            ];
          };
        }
      ];
      grid_options = {
        columns = "full";
        rows = "auto";
      };
    })
    (mkGridSection {
      cards = [
        (mkHeading {
          heading = "Cameras";
          icon = "mdi:cctv";
        })
        {
          type = "custom:auto-entities";
          card = {
            type = "grid";
            columns = 2;
            square = false;
          };
          card_param = "cards";
          filter = {
            include = [
              {
                domain = "camera";
                options = {
                  type = "picture-entity";
                  camera_view = "live";
                  show_state = false;
                };
              }
            ];
          };
        }
      ];
      grid_options = {
        columns = "full";
        rows = "auto";
      };
    })
    (mkGridSection {
      cards = [
        (mkHeading {
          heading = "Open Doors & Windows";
          icon = "mdi:door";
        })
        {
          type = "custom:auto-entities";
          card.type = "entities";
          sort.method = "name";
          filter = {
            exclude = [ ];
            include = [
              {
                domain = "binary_sensor";
                attributes.device_class = "door";
                state = "on";
              }
              {
                domain = "binary_sensor";
                attributes.device_class = "window";
                state = "on";
              }
            ];
          };
        }
      ];
      grid_options = {
        columns = "full";
        rows = "auto";
      };
    })
  ];

  theme = "Rounded-Bubble";
  dense_section_placement = false;
}
