{ inputs, lib, ... }:
let
  takePackages =
    system: input: names:
    let
      packages = input.packages or input.legacyPackages;
    in
    lib.foldl' (acc: name: acc // { ${name} = packages.${system}.${name}; }) { } names;

  # If given a string, assumes the input and package name are the same.
  # Otherwise should be defined as an attr with the input and the package name(s).
  packagesFromOtherInstances = [
    "nixd"
    "nil"
    "quickshell"
  ];
in
{
  # Packages taken from other instances of nixpkgs inputs, (i.e) pr branches and the like.
  fromOtherInstances =
    final: _prev:
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
      (map ({ input, packages }: takePackages final.system input packages))
      (lib.foldl' lib.recursiveUpdate { })
    ];

  additions =
    final: prev:
    prev.lib.foldl' prev.lib.recursiveUpdate { } [
      (import ../pkgs {
        inherit inputs;
        pkgs = final;
      })
    ];

  modifications = final: prev: {
    nautilus = prev.nautilus.overrideAttrs (oldAttrs: {
      buildInputs = oldAttrs.buildInputs ++ [
        final.gst_all_1.gst-plugins-good
        final.gst_all_1.gst-plugins-bad
        final.gst_all_1.gst-plugins-ugly
      ];
    });

    discord = prev.discord.override {
      withOpenASAR = true;
      withVencord = true;
      nss = final.nss_latest;
    };

    bottles = prev.bottles.override {
      removeWarningPopup = true;
    };

    quickshell = prev.quickshell.overrideAttrs (oldAttrs: {
      buildInputs = oldAttrs.buildInputs or [ ] ++ [
        final.qt6.full
        final.kdePackages.kirigami
      ];
    });

    inherit lib;
  };

  electronFixes =
    _: prev:
    lib.optionalAttrs prev.config.cudaSupport (
      prev.lib.pipe
        [ "vscode" "obsidian" ]
        [
          (map (
            name:
            prev.lib.nameValuePair name (
              prev.${name}.override {
                commandLineArgs = "--disable-gpu-compositing --enable-features=WebRTCPipeWireCapturer";
              }
            )
          ))
          prev.lib.listToAttrs
        ]
    );
}
