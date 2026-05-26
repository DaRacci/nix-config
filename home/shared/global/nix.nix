{
  inputs,
  pkgs,
  lib,
  ...
}:
{
  nix = {
    package = lib.mkForce pkgs.lix;
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
    (_final: prev: {
      zjstatus = inputs.zjstatus.packages.${prev.stdenv.hostPlatform.system}.default;
    })
  ];
}
