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
    concatStringsSep
    path
    ;
in
rec {
  writeNuApplication =
    {
      name,
      runtimeInputs ? [ ],
      sourceRoot,
      pkgs,
      extraDrv ? { },
    }:
    pkgs.writeTextFile (
      {
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
      }
      // extraDrv
    );

  writeNuApplicationWithLibs =
    {
      name,
      runtimeInputs ? [ ],
      sourceRoot,
      libSource ? null,
      pkgs,
    }:
    let
      sourceStore = path {
        path = sourceRoot;
        name = "${name}-source";
      };
      libStore =
        if libSource == null then
          sourceStore + "/lib"
        else
          path {
            path = libSource;
            name = "${name}-lib";
          };
    in
    writeNuApplication {
      inherit
        name
        runtimeInputs
        sourceRoot
        pkgs
        ;

      extraDrv.checkPhase =
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

      passthru.discovery = false;
    };
}
