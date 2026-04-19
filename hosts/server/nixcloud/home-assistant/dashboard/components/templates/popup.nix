{ lib, ... }:
with (import ../../lib.nix { inherit lib; });
{
  popup =
    {
      location,
    }:
    {
      type = "custom:bubble-card";
      card_type = "pop-up";
      hash = "#${location}";
      button_type = "name";

    };
}
