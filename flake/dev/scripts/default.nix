{
  pkgs,
  lib,
  ...
}:
let
  inherit (lib.mine.packages) writeNuApplicationWithLibs;
in
{
  install-vale-dictionaries = writeNuApplicationWithLibs {
    inherit pkgs;
    sourceRoot = ./.;
    name = "install-vale-dictionaries";
    runtimeInputs = [ pkgs.ripgrep ];
  };

  vale-tech-dictionary =
    pkgs.runCommandLocal "vale-tech-dictionary"
      {
        CSPELL = pkgs.cspell;
        nativeBuildInputs = [
          pkgs.gzip
          pkgs.nushell
        ];
      }
      ''
        nu ${./vale-tech-dictionary.nu}
      '';

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
