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
      (usePR [ "boxflat" ] "DaRacci" "boxflat" "sha256-+Rz1Cb0ALFhh4v+yf3og5v0F0Tt1Qc7mznUyZIebSBw=")
    ];

  modifications = final: prev: {
    steamtinkerlaunch = prev.steamtinkerlaunch.overrideAttrs (_oldAttrs: {
      postPatch = ''
        substituteInPlace steamtinkerlaunch --replace 'PROGCMD="''${0##*/}"' 'PROGCMD="steamtinkerlaunch"'
        substituteInPlace steamtinkerlaunch --replace 'YAD=yad' 'YAD=${final.yad}'
      '';
    });

    discord =
      let
        nss =
          if final.stdenv.buildPlatform.isLinux then
            {
              nss = final.nss_latest;
            }
          else
            { };
      in
      final.discord.override ({ withOpenASAR = true; } // nss);

    cliphist = prev.cliphist.overrideAttrs (_old: {
      src = final.fetchFromGitHub {
        owner = "sentriz";
        repo = "cliphist";
        rev = "c49dcd26168f704324d90d23b9381f39c30572bd";
        sha256 = "sha256-2mn55DeF8Yxq5jwQAjAcvZAwAg+pZ4BkEitP6S2N0HY=";
      };
      vendorHash = "sha256-M5n7/QWQ5POWE4hSCMa0+GOVhEDCOILYqkSYIGoy/l0=";
    });

    inherit lib;
    inherit (inputs.nixd.packages.x86_64-linux) nixd;
  };
}
