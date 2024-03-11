{ config, pkgs, ... }: {
  home.packages = with pkgs; [ unstable.satty grim slurp ];

  
}