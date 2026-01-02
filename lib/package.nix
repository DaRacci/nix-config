{
  lib,
  ...
}:
let
  inherit (lib)
    getExe
    makeBinPath
    filter
    hasSuffix
    ;
  inherit (builtins)
    readFile
    readDir
    attrNames
    map
    concatStringsSep
    ;
in
{
  writeNuApplicationWithLibs =
    {
      name,
      runtimeInputs ? [ ],
      sourceRoot,
      pkgs,
    }:
    pkgs.writeTextFile {
      inherit name;

      executable = true;
      destination = "/bin/${name}";
      allowSubstitutes = true;
      preferLocalBuild = false;
      text = ''
        #!${getExe pkgs.nushell}

        $env.PATH = ($env.PATH | split row (char esep) | (prepend $"${
          makeBinPath (
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
        ${readFile "${sourceRoot}/${name}.nu"}
      '';
      checkPhase =
        let
          libDir = "${sourceRoot}/lib";
        in
        ''
          mkdir -p $out/bin/lib

          ${
            if builtins.pathExists libDir then
              readDir "${sourceRoot}/lib"
              |> attrNames
              |> filter (libFile: hasSuffix "nu" libFile)
              |> map (libFile: "cp ${"${sourceRoot}/lib/${libFile}"} $out/bin/lib/${libFile}")
              |> concatStringsSep "\n"
            else
              ""
          }
        '';
    };
}
