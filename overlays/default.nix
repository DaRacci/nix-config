{
  inputs,
  lib,
}:
let
  takePackages =
    system: input: names:
    let
      packages = input.packages or input.legacyPackages;
    in
    lib.foldl' (acc: name: acc // { ${name} = packages.${system}.${name}; }) { } names;

  # If given a string, assumes the input and package name are the same.
  # Otherwise should be defined as an attr with the input and the package name(s).
  packagesFromOtherInstances = [ ];
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
      (map ({ input, packages }: takePackages final.stdenv.hostPlatform.system input packages))
      (lib.foldl' lib.recursiveUpdate { })
    ];

  additions =
    final: prev:
    (prev.lib.foldl' prev.lib.recursiveUpdate { } [
      (import ../pkgs {
        inherit inputs lib;
        pkgs = final;
      })
    ])
    // {
      mcpo = prev.python3Packages.callPackage inputs.mcpo { };

      lm_sensors-perlless = prev.lm_sensors.overrideAttrs (oldAttrs: {
        buildInputs = oldAttrs.buildInputs |> (lib.remove prev.perl);
      });
    };

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

    open-webui = prev.open-webui.overridePythonAttrs (oldAttrs: {
      dependencies = oldAttrs.dependencies ++ [
        prev.python3Packages.itsdangerous
      ];
    });

    statix = prev.statix.overrideAttrs (_: rec {
      src = prev.fetchFromGitHub {
        owner = "oppiliappan";
        repo = "statix";
        rev = "43681f0da4bf1cc6ecd487ef0a5c6ad72e3397c7";
        hash = "sha256-LXvbkO/H+xscQsyHIo/QbNPw2EKqheuNjphdLfIZUv4=";
      };

      cargoDeps = prev.rustPlatform.importCargoLock {
        lockFile = src + "/Cargo.lock";
        allowBuiltinFetchGit = true;
      };
    });

    # TODO Remove once #480983 lands in nixos-unstable
    hyprland = prev.hyprland.overrideAttrs (_: {
      postPatch = ''
        # Fix hardcoded paths to /usr installation
        substituteInPlace src/render/OpenGL.cpp \
          --replace-fail /usr $out

        # Remove extra @PREFIX@ to fix pkg-config paths
        substituteInPlace hyprland.pc.in \
          --replace-fail  "@PREFIX@/" ""
        substituteInPlace example/hyprland.desktop.in \
          --replace-fail  "@PREFIX@/" ""
      '';
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
