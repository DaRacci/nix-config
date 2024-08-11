{ inputs, lib, ... }:
let
  usePRRaw = final: prev: names: owner: branch: sha256:
    let
      overlay = import
        (final.fetchzip {
          inherit sha256;
          url = "https://github.com/${owner}/nixpkgs/archive/${branch}.tar.gz";
        })
        { overlays = [ ]; inherit (prev) config; };
    in
    lib.foldl'
      (acc: name: acc // {
        ${name} = overlay.${name};
      })
      { }
      names;
in
{
  additions = final: prev:
    let usePR = usePRRaw final prev; in
    prev.lib.foldl' prev.lib.recursiveUpdate { } [
      # This one brings our custom packages from the 'pkgs' directory
      (import ../pkgs { pkgs = final; })
      (usePR [ "protonup-rs" ] "liperium" "protonuprs-init" "sha256-z5Zh+ih0gE+Uwl8b7//apBRbrsHTvpV0PAhQwM8mOZ4=")
    ];

  # This one contains whatever you want to overlay
  # You can change versions, add patches, set compilation flags, anything really.
  # https://nixos.wiki/wiki/Overlays
  modifications = final: prev:
    {
      steamPackages = prev.steamPackages.overrideScope (_steamFinal: steamPrev: {
        # Appends the -noverify flag to steam so we can modify some if its files :)
        steam = steamPrev.steam.overrideAttrs (oldAttrs: {
          # postInstall = builtins.replaceStrings [ "'s,/usr/bin/steam,steam,g'" ] [ "'s,/usr/bin/steam,steam -bigpicture -noverifyfiles,g'" ] oldAttrs.postInstall;
          postInstall = builtins.replaceStrings [ "'s,/usr/bin/steam,steam,g'" ] [ "'s,/usr/bin/steam,${final.gamescope}/bin/gamescope -e -f -- steam -tenfoot -noverifyfiles,g'" ] oldAttrs.postInstall;
        });
      });

      steamtinkerlaunch = prev.steamtinkerlaunch.overrideAttrs (_oldAttrs: {
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

      linuxKernel = prev.linuxKernel // {
        packagesFor = kernel: prev.linuxKernel.packagesFor kernel // {
          universal-pidff = prev.callPackage "${(final.fetchzip {
              sha256 = "sha256-BbKrKAdFNTZU5tx7HeP3tWb/aDg00MJNC9w/3nvpJD4=";
              url = "https://github.com/danerieber/nixpkgs/archive/universal-pidff.tar.gz";
            })}/pkgs/os-specific/linux/universal-pidff"
            { inherit kernel; };
        };
      };

      inherit lib;
      inherit (inputs.nixd.packages.x86_64-linux) nixd;
      inherit (inputs.moza-racing.packages) boxflat;
    };

  # When applied, the unstable nixpkgs set (declared in the flake inputs) will
  # be accessible through 'pkgs.unstable'
  unstable-packages = final: _prev: {
    unstable = import inputs.nixpkgs-unstable {
      inherit (final) system;
      config.allowUnfree = true;
    };
  };
}
