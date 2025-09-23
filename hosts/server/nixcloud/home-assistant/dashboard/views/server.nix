{ lib, ... }:
with (import ../lib.nix { inherit lib; });
let
  navbar = import ../components/navbar.nix { };
  viewHeader = import ../components/view-header.nix {
    content = ''
      # Server
    '';
  };
in
mkView {
  title = "Server";
  header = viewHeader;
  path = "server";
  icon = "mdi:server-outline";

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
          icon = "mdi:server";
        })
        {
          type = "entities";
          entities = [
            "sensor.media_player_active"
            "sensor.battery_level_attention"
            "sensor.battery_health_attention"
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
          heading = "3D Printer";
          icon = "mdi:printer-3d";
        })
        {
          type = "conditional";
          conditions = [
            (condState {
              entity = "sensor.k1c_276e_current_print_state";
              state = "printing";
            })
          ];
          card = (
            mkVerticalStack {
              cards = [
                {
                  type = "gauge";
                  entity = "sensor.k1c_276e_progress";
                  name = "Print Progress";
                  min = 0;
                  max = 100;
                  severity = {
                    green = 50;
                    yellow = 80;
                    red = 95;
                  };
                }
                {
                  type = "entity";
                  entity = "sensor.k1c_276e_current_print_state";
                  name = "State";
                }
              ];
            }
          );
        }
        {
          type = "conditional";
          conditions = [
            (condState {
              entity = "sensor.k1c_276e_current_print_state";
              state_not = "printing";
            })
          ];
          card = {
            type = "markdown";
            content = "No active print";
          };
        }
      ];
      grid_options = {
        columns = "full";
        rows = "auto";
      };
    })
  ];
}
