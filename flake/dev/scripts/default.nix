{
  pkgs,
  lib,
}:
let
  writeNuApplicationWithLibs =
    {
      name,
      runtimeInputs ? [ ],
      source,
    }:
    pkgs.writeTextFile {
      inherit name;

      executable = true;
      destination = "/bin/${name}";
      allowSubstitutes = true;
      preferLocalBuild = false;
      text = ''
        #!${lib.getExe pkgs.nushell}

        $env.PATH = ($env.PATH | split row (char esep) | (prepend $"${
          lib.makeBinPath (
            runtimeInputs
            ++ [
              pkgs.nix
              pkgs.git
              pkgs.busybox
            ]
          )
        }" | split row (char esep)))
      ''
      + ''
        ${builtins.readFile source}
      '';
      checkPhase = ''
        mkdir -p $out/bin/lib

        ${
          builtins.readDir ./lib
          |> builtins.attrNames
          |> builtins.map (libFile: "cp ${./lib/${libFile}} $out/bin/lib/${libFile}")
          |> builtins.concatStringsSep "\n"
        }
      '';
    };
in
{
  nix-tree-host = writeNuApplicationWithLibs {
    name = "nix-tree-host";
    runtimeInputs = [ pkgs.nix-tree ];
    source = ./nix-tree-host.nu;
  };

  rebuild-target = writeNuApplicationWithLibs {
    name = "rebuild-target";
    runtimeInputs = [ pkgs.nh ];
    source = ./rebuild-target.nu;
  };
}
