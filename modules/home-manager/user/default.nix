{ flake, config, lib, ... }: with lib; let cfg = config.user; in {
  imports = [
    ./persistence.nix
  ];

  options.user = { };

  config = { };
}
