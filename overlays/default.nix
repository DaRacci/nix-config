{ inputs, lib, ... }:
let
  takePackages =
    input: names:
    let
      packages = input.packages or input.legacyPackages;
    in
    lib.foldl' (acc: name: acc // { ${name} = packages.${builtins.currentSystem}.${name}; }) { } names;

  # If given a string, assumes the input and package name are the same.
  # Otherwise should be defined as an attr with the input and the package name(s).
  packagesFromOtherInstances = [
    "protonup-rs"
    "nixd"
    "lact"
  ];
in
{
  # Packages taken from other instances of nixpkgs inputs, (i.e) pr branches and the like.
  fromOtherInstances =
    _final: _prev:
    lib.pipe packagesFromOtherInstances [
      (map (
        input:
        if lib.isAttrs input && input ? packages && input ? input then
          input
        else if lib.isString input then
          {
            input = inputs.${input};
            packages = [ input ];
          }
        else
          throw "Invalid input format."
      ))
      (map ({ input, packages }: takePackages input packages))
      (lib.foldl' lib.recursiveUpdate { })
    ];

  additions =
    final: prev:
    prev.lib.foldl' prev.lib.recursiveUpdate { } [
      (import ../pkgs { pkgs = final; })
    ];

  modifications = final: prev: {
    steamtinkerlaunch = prev.steamtinkerlaunch.overrideAttrs (_oldAttrs: {
      postPatch = ''
        substituteInPlace steamtinkerlaunch --replace 'PROGCMD="''${0##*/}"' 'PROGCMD="steamtinkerlaunch"'
        substituteInPlace steamtinkerlaunch --replace 'YAD=yad' 'YAD=${final.yad}'
      '';
    });

    lact = prev.lact.overrideAttrs (oldAttrs: {
      nativeBuildInputs = oldAttrs.nativeBuildInputs ++ [ final.autoAddDriverRunpath ];
    });

    inherit lib;
  };
}
