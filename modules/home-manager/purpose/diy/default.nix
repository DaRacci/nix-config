{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.purpose.diy;
in
{
  imports = [
    ./printing.nix
  ];

  options.purpose.diy = {
    enable = lib.mkEnableOption "diy";
  };

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [

    ];
  };
}
