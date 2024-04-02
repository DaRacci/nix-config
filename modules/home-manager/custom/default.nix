{ config, lib, ... }: with lib; {
  imports = [
    ./fonts.nix
    ./theme.nix
  ];

  options.custom = { };

  config = { };
}
