{ lib }:
let
  viewHeader = import ../components/view-header.nix { };
  navbar = import ../components/navbar.nix { };
  adminPanel = import ../components/admin-panel.nix;
in
with (import ../lib.nix { inherit lib; });
mkView {
  title = "Home";
  header = viewHeader;
  path = "home";
  icon = "mdi:home-assistant";

  badges = standardBadges;

  sections = [
    (mkGridSection {
      cards = [
        navbar
        adminPanel
      ];
      grid_options = {
        columns = "full";
        rows = "auto";
      };
    })
  ];
}
