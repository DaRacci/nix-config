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

    mcpo = prev.mcpo.overridePythonAttrs (oldAttrs: rec {
      version = "0.0.17";
      src = oldAttrs.src.override {
        tag = "v${version}";
        hash = "sha256-oubMRHiG6JbfMI5MYmRt4yNDI8Moi4h7iBZPgkdPGd4=";
      };
      dependencies = oldAttrs.dependencies ++ [
        final.python3Packages.watchdog
      ];
    });

    python3Packages = prev.python3Packages.overrideScope (
      final: prev: {
        mcp = prev.mcp.overridePythonAttrs (oldAttrs: rec {
          version = "1.12.2";
          src = oldAttrs.src.override {
            tag = "v${version}";
            hash = "sha256-K3S+2Z4yuo8eAOo8gDhrI8OOfV6ADH4dAb1h8PqYntc=";
          };
          postPatch = oldAttrs.postPatch |> builtins.replaceStrings [ "1.9.4" ] [ version ];
          dependencies = oldAttrs.dependencies ++ [
            final.jsonschema
          ];
          nativeCheckInputs = oldAttrs.nativeCheckInputs ++ [
            final.dirty-equals
          ];
          disabledTests = oldAttrs.disabledTests ++ [
            "test_func_metadata"
            "test_lifespan_cleanup_executed"
          ];
        });
      }
    );

    inherit lib;
  };

  electronFixes =
    _: prev:
    lib.optionalAttrs prev.config.cudaSupport (
      prev.lib.pipe
        [ "vscode" "obsidian" "protonmail-desktop" ]
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
