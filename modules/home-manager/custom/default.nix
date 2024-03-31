{ config, lib, ... }: with lib; let cfg = config.custom; in {
  imports = [
    ./fonts.nix
    ./theme.nix
  ];

  options.custom = { };

  config = { };
}
