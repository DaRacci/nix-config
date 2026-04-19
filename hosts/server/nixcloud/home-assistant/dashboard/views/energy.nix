{ lib, ... }:
let
  viewHeader = import ../components/view-header.nix {
    content = ''
      # Energy
    '';
  };

  navbar = import ../components/navbar.nix { inherit lib; };
in
with (import ../lib.nix { inherit lib; });
mkView {
  title = "Energy";
  header = viewHeader;
  path = "energy";
  icon = "mdi:lightning-bolt";

  badges = [ ];

  sections = [
    (mkGridSection {
      cards = [ navbar ];
    })

    (mkGridSection {
      cards = [
        (mkHeading {
          heading = "Overview";
          icon = "mdi:lightning-bolt";
        })
        { type = "energy-grid-neutrality-gauge"; }
        { type = "energy-sources-table"; }
      ];
    })

    (mkGridSection {
      cards = [
        (mkHeading {
          heading = "Electricity";
          icon = "mdi:home-lightning-bolt";
        })
        { type = "energy-usage-graph"; }
        { type = "energy-distribution"; }
      ];
    })

    (mkGridSection {
      cards = [
        (mkHeading {
          heading = "Power";
          icon = "mdi:flash";
        })
        {
          type = "history-graph";
          hours_to_show = 24;
          entities = [
            { entity = "sensor.power_consumption"; }
          ];
        }
      ];
    })

    (mkGridSection {
      cards = [
        (mkHeading {
          heading = "Sensors";
          icon = "mdi:gauge";
        })
        {
          type = "energy-date-selection";
        }
        {
          type = "energy-solar-consumed-gauge";
        }
      ];
    })
  ];
}
