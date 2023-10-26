{ flake, ... }: {

  imports = [
    flake.inputs.nixos-wsl.nixosModules.wsl
    ./hardware.nix
    ../common/optional/wsl.nix
  ];
}
