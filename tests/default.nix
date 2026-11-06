{
  pkgs,
  lib,
}:
{
  woodpecker-store = import ./vm/woodpecker-store.nix { inherit pkgs lib; };
}
