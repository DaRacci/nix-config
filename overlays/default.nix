# This file defines overlays
{ inputs, getchoo, ... }: {
  # This one brings our custom packages from the 'pkgs' directory
  additions = final: _prev: import ../pkgs {
    pkgs = final;
    inherit getchoo;
  };

  # This one contains whatever you want to overlay
  # You can change versions, add patches, set compilation flags, anything really.
  # https://nixos.wiki/wiki/Overlays
  modifications = final: prev: {
    steamPackages = prev.steamPackages.overrideScope (steamFinal: steamPrev: {
      # Appends the -noverify flag to steam so we can modify some if its files :)
      steam = steamPrev.steam.overrideAttrs (oldAttrs: {
        postInstall = builtins.replaceStrings [ "'s,/usr/bin/steam,steam,g'" ] [ "'s,/usr/bin/steam,steam -bigpicture -noverifyfiles,g'" ] oldAttrs.postInstall;
      });
    });

    steamtinkerlaunch = prev.steamtinkerlaunch.overrideAttrs (oldAttrs: {
      postPatch = ''
        substituteInPlace steamtinkerlaunch --replace 'PROGCMD="''${0##*/}"' 'PROGCMD="steamtinkerlaunch"'
        substituteInPlace steamtinkerlaunch --replace 'YAD=yad' 'YAD=${final.yad}'
      '';
    });
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
