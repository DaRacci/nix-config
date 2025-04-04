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
    "flaresolverr"
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

    orca-slicer = prev.orca-slicer.overrideAttrs (oldAttrs: {
      cmakeFlags = oldAttrs.cmakeFlags ++ [
        (lib.cmakeFeature "CUDA_TOOLKIT_ROOT_DIR" "${prev.cudaPackages.cudatoolkit}")
      ];
      preFixup =
        builtins.replaceStrings
          [ ")\n" ]
          [
            ''
              --set __GLX_VENDOR_LIBRARY_NAME mesa
              --set __EGL_VENDOR_LIBRARY_FILENAMES ${prev.mesa}/share/glvnd/egl_vendor.d/50_mesa.json
              --set MESA_LOADER_DRIVER_OVERRIDE zink
              --set GALLIUM_DRIVER zink
              )
            ''
          ]
          oldAttrs.preFixup;
    });

    nautilus = prev.nautilus.overrideAttrs (oldAttrs: {
      buildInputs = oldAttrs.buildInputs ++ [
        final.gst_all_1.gst-plugins-good
        final.gst_all_1.gst-plugins-bad
        final.gst_all_1.gst-plugins-ugly
      ];
    });

    discord = prev.discord.override {
      # OpenASAR completely breaks Discord
      # withOpenASAR = true;
      withVencord = true;
      nss = final.nss_latest;
    };

    parted = prev.parted.overrideAttrs (oldAttrs: {
      buildInputs = oldAttrs.buildInputs ++ [
        final.zfs
        final.btrfs-progs
        final.cryptsetup
      ];
    });

    inherit lib;
  };

  electronFixes =
    _: prev:
    lib.mkIf prev.config.cudaSupport (
      prev.lib.pipe
        [ "vscode" "obsidian" ]
        [
          (map (
            name:
            prev.lib.nameValuePair name (
              prev.${name}.override {
                commandLineArgs = "--disable-gpu-compositing";
              }
            )
          ))
          prev.lib.listToAttrs
        ]
    );
}
