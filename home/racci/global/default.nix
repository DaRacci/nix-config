{ config, inputs, lib, modulesPath, ... }:

let
  colourScheme = inputs.nix-colours.colorSchemes.onedark;
  inherit (config.home) username;
in
{
  imports = [
    (modulesPath + "/home/${username}/features/cli")
    (modulesPath + /home/${username}/features/daemons)
  ];

  home.file.".colorscheme".text = colourScheme.slug;
  colorscheme = lib.mkDefault colourScheme;
}
