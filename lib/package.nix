{
  lib,
  ...
}:
let
  inherit (lib)
    getExe
    makeBinPath
    ;
  inherit (builtins)
    readFile
    path
    ;
in
{
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
              pkgs.jq
              pkgs.nix
              pkgs.git
              pkgs.busybox
            ]
          )
        }" | split row (char esep)))
      ''
      + ''
        ${readFile "${sourceStore}/${name}.nu"}
      '';
      checkPhase = ''
        mkdir -p "$out/bin/lib"

        find ${libStore} -maxdepth 1 -type f -name '*.nu' -print0 \
          | xargs -0 -r cp -t "$out/bin/lib"
      '';

      passthru.discovery = false;
    };
}
