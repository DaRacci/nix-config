{ inputs, lib, ... }:
let
  usePRRaw =
    final: prev: names: owner: branch: sha256:
    let
      overlay =
        import
          (final.fetchzip {
            inherit sha256;
            url = "https://github.com/${owner}/nixpkgs/archive/${branch}.tar.gz";
          })
          {
            overlays = [ ];
            inherit (prev) config;
          };
    in
    lib.foldl' (acc: name: acc // { ${name} = overlay.${name}; }) { } names;
in
{
  additions =
    final: prev:
    let
      usePR = usePRRaw final prev;
    in
    prev.lib.foldl' prev.lib.recursiveUpdate { } [
      # This one brings our custom packages from the 'pkgs' directory
      (import ../pkgs { pkgs = final; })
      (usePR [
        "protonup-rs"
      ] "liperium" "protonuprs-init" "sha256-z5Zh+ih0gE+Uwl8b7//apBRbrsHTvpV0PAhQwM8mOZ4=")
      (usePR [ "boxflat" ] "DaRacci" "boxflat" "sha256-38PXVNBXg0KcSccl9QNq7q/dYCXFD601+sdIaljzwIw=")
    ];

  modifications = final: prev: {
    steamtinkerlaunch = prev.steamtinkerlaunch.overrideAttrs (_oldAttrs: {
      postPatch = ''
        substituteInPlace steamtinkerlaunch --replace 'PROGCMD="''${0##*/}"' 'PROGCMD="steamtinkerlaunch"'
        substituteInPlace steamtinkerlaunch --replace 'YAD=yad' 'YAD=${final.yad}'
      '';
    });

    inherit lib;
    inherit (inputs.nixd.packages.x86_64-linux) nixd;
  };
}
