{ lib, ... }:
let
  viewHeader = import ../components/view-header.nix {
    content = ''
      # Energy
    '';
  };

  navbar = import ../components/navbar.nix { };
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
          type = "markdown";
          content = "Add power graphs (e.g., history-graph/statistics-graph) for your power sensors here.";
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
          type = "markdown";
          content = "Add your energy-related sensors (e.g., daily energy, grid import/export) to an Entities card here.";
        }
        {
          type = "entities";
          entities = [ ];
        }
      ];
    })
  ];
}
