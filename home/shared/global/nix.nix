{
  inputs,
  pkgs,
  lib,
  ...
}:
{
  nix = {
    package = lib.mkDefault pkgs.nix;
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
        "pipe-operator"
      ];
      warn-dirty = false;
    };
  };

  nixpkgs.overlays = [
    inputs.nix4vscode.overlays.default
  ];
}
