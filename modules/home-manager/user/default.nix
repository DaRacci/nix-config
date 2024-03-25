{ config, lib, ... }: with lib; let cfg = config.user; in {
  imports = [
    ./autorun.nix
    ./persistence.nix
  ];

  options.user = { };

  config = { };
}
