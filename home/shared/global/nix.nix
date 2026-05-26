{
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

}
