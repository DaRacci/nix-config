{ config, lib, ... }: with lib; {
  imports = [
    ./autorun.nix
    ./persistence.nix
  ];

  options.user = { };

  config = { };
}
