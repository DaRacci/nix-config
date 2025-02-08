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
      (usePR [ "boxflat" ] "DaRacci" "boxflat" "sha256-r21PBcWYqZvME+1lYbR+6BReR4iv2pBeZ2IQXAZ+iF0=")
    ];

  modifications = final: prev: {
    steamtinkerlaunch = prev.steamtinkerlaunch.overrideAttrs (_oldAttrs: {
      postPatch = ''
        substituteInPlace steamtinkerlaunch --replace 'PROGCMD="''${0##*/}"' 'PROGCMD="steamtinkerlaunch"'
        substituteInPlace steamtinkerlaunch --replace 'YAD=yad' 'YAD=${final.yad}'
      '';
    });

    # TODO: Find a way to do this without having to recompile the package
    vesktop = prev.vesktop.overrideAttrs (oldAttrs: {
      postFixup =
        oldAttrs.postFixup
        + ''
          substituteInPlace $out/bin/vesktop --replace '--enable-features=WaylandWindowDecorations' '--enable-features=WaylandWindowDecorations --disable-gpu-compositing'
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

    oscavmgr = prev.oscavmgr.overrideAttrs (_oldAttrs: {
      patches = [ ./oscavmgr_header.patch ];
    });

    inherit lib;
    inherit (inputs.nixd.packages.x86_64-linux) nixd;
  };
}
