{ inputs, ... }:

let
  inherit (inputs.nix-colours) colourSchemes;
in {
  imports = [
    ./global 
  ]; 
}