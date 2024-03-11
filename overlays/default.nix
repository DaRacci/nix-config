# This file defines overlays
{ self, inputs, getchoo, ... }:
let
  usePRRaw = final: prev: name: owner: branch: sha256: {
    ${name} = (import
      (final.fetchzip {
        inherit sha256;
        url = "https://github.com/${owner}/nixpkgs/archive/${branch}.tar.gz";
      })
      { overlays = [ ]; config = prev.config; }).${name};
  };
in
{
  # This one brings our custom packages from the 'pkgs' directory
  additions = final: prev:
    let usePR = usePRRaw final prev; in prev.lib.foldl' prev.lib.recursiveUpdate { } [
      (import ../pkgs { system = final.system; pkgs = final; inherit getchoo; })
      (usePR "coolercontrol" "codifryed" "coolercontrol-0.17.0" "sha256-UXznzCmBpSFELFuztM7KSS+R1a1vWBYZBISARafu+OA=")
      # (usePR "jetbrains" "sofuture" "jz/update-jetbrains" "sha256-p5rF9ACM2JRQDlpNuOWDEDTIkZ+S9Tp7nUicD9bZ758=")
    ];

  # This one contains whatever you want to overlay
  # You can change versions, add patches, set compilation flags, anything really.
  # https://nixos.wiki/wiki/Overlays
  modifications = final: prev:
    let usePR = usePRRaw final prev; in {
      steamPackages = prev.steamPackages.overrideScope (steamFinal: steamPrev: {
        # Appends the -noverify flag to steam so we can modify some if its files :)
        steam = steamPrev.steam.overrideAttrs (oldAttrs: {
          # postInstall = builtins.replaceStrings [ "'s,/usr/bin/steam,steam,g'" ] [ "'s,/usr/bin/steam,steam -bigpicture -noverifyfiles,g'" ] oldAttrs.postInstall;
          postInstall = builtins.replaceStrings [ "'s,/usr/bin/steam,steam,g'" ] [ "'s,/usr/bin/steam,${final.gamescope}/bin/gamescope -e -f -- steam -tenfoot -noverifyfiles,g'" ] oldAttrs.postInstall;
        });
      });

      steamtinkerlaunch = prev.steamtinkerlaunch.overrideAttrs (oldAttrs: {
        postPatch = ''
          substituteInPlace steamtinkerlaunch --replace 'PROGCMD="''${0##*/}"' 'PROGCMD="steamtinkerlaunch"'
          substituteInPlace steamtinkerlaunch --replace 'YAD=yad' 'YAD=${final.yad}'
        '';
      });

      discord =
        let
          nss =
            if final.stdenv.buildPlatform.isLinux
            then { nss = final.nss_latest; }
            else { };
        in
        final.discord.override ({ withOpenASAR = true; } // nss);

      lib = prev.lib // {
        mine = (import ../lib { inherit (final) system; inherit self inputs; }).lib;
      };

      nixd = inputs.nixd.packages.x86_64-linux.nixd;
    };

  # When applied, the unstable nixpkgs set (declared in the flake inputs) will
  # be accessible through 'pkgs.unstable'
  unstable-packages = final: _prev: {
    unstable = import inputs.nixpkgs-unstable {
      system = final.system;
      config.allowUnfree = true;
    };
  };
}
