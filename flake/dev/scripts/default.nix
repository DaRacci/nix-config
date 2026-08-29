{
  pkgs,
  lib,
  ...
}:
let
  inherit (lib.mine.packages) writeNuApplicationWithLibs;
in
{
  nix-tree-host = writeNuApplicationWithLibs {
    inherit pkgs;
    sourceRoot = ./.;
    name = "nix-tree-host";
    runtimeInputs = [ pkgs.nix-tree ];
  };

  rebuild-target = writeNuApplicationWithLibs {
    inherit pkgs;
    sourceRoot = ./.;
    name = "rebuild-target";
    runtimeInputs = [ pkgs.nh ];
  };

  update-redis-mappings = writeNuApplicationWithLibs {
    inherit pkgs;
    sourceRoot = ./.;
    name = "update-redis-mappings";
    runtimeInputs = [ pkgs.lix ];
  };

  update-sops = writeNuApplicationWithLibs {
    inherit pkgs;
    sourceRoot = ./.;
    name = "update-sops";
    runtimeInputs = [
      pkgs.sops
      pkgs.ssh-to-age
    ];
  };
}
