{
  lib,
  ...
}:
let
  inherit (lib)
    getExe
    makeBinPath
    filter
    filterAttrs
    ;
  inherit (builtins)
    readFile
    readDir
    attrNames
    concatStringsSep
    pathExists
    ;

  nuLib = ./nu-lib;
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

        passthru.discovery = false;
        passthru.ci = false;
      }
      // extraDrv
    );

  writeNuApplicationWithLibs =
    {
      name,
      runtimeInputs ? [ ],
      sourceRoot,
      pkgs,
    }:
    writeNuApplication {
      inherit
        name
        runtimeInputs
        sourceRoot
        pkgs
        ;

      extraDrv.checkPhase =
        let
          libDirs = filter pathExists [
            "${sourceRoot}/lib"
            nuLib
          ];
          copyLibDir = libDir: ''
            ${concatStringsSep "\n" (
              map (libFile: "cp ${libDir}/${libFile} $out/bin/lib/${libFile}") (
                attrNames (filterAttrs (_: type: type == "regular") (readDir libDir))
              )
            )}
          '';
        in
        ''
          mkdir -p $out/bin/lib

          ${concatStringsSep "\n" (map copyLibDir libDirs)}
        '';

    };
}
