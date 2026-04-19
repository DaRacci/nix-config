{ lib }:
let
  dashLib = import ./lib.nix { inherit lib; };
  inherit (dashLib) entities;
in
{
  non_admin_settings = {
    hide_header = true;
    ignore_entity_settings = true;
  };
  entity_settings = [
    {
      entity.${entities.inputBooleans.debugRounded} = "on";
      hide_header = false;
    }
    {
      entity.${entities.inputBooleans.debugRounded} = "off";
      hide_header = true;
    }
  ];
}
