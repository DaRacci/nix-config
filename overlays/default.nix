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
  singleton = import ./singleton.nix {
    inherit inputs lib;
  };

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
      lm_sensors-perlless = prev.lm_sensors.overrideAttrs (oldAttrs: {
        buildInputs = oldAttrs.buildInputs |> (lib.remove prev.perl);
      });

      fastembed-hermes =
        inputs.hermes-agent.packages.${final.stdenv.hostPlatform.system}.default.python.pkgs.fastembed.overridePythonAttrs
          (old: {
            dependencies = builtins.filter (
              dep:
              let
                name = lib.getName dep;
              in
              # Hermes uv2nix env already has these deps and complains about collisions.
              !(builtins.any (n: lib.hasInfix n name) [
                "huggingface-hub"
                "numpy"
                "onnxruntime"
                "pillow"
                "requests"
                "snowballstemmer"
                "tokenizers"
                "tqdm"
              ])
            ) old.dependencies;
            dontCheckRuntimeDeps = true;
            pythonImportsCheck = [ ];
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
      #TODO:https://github.com/NixOS/nixpkgs/pull/584169
      withVencord = false;
    };

    bottles = prev.bottles.override {
      removeWarningPopup = true;
    };

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

    kernelPackagesExtensions = prev.kernelPackagesExtensions ++ [
      (_self: _super: { })
    ];

    pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
      (_python-final: python-prev: {
        inline-snapshot = python-prev.inline-snapshot.overridePythonAttrs (_: {
          doCheck = false;
        });
      })
    ];

    inherit lib;
  };

  electronCudaFixes =
    _: prev:
    lib.optionalAttrs prev.config.cudaSupport (
      [
        "vscode"
        "obsidian"
      ]
      |> map (
        name:
        prev.lib.nameValuePair name (
          prev.${name}.override {
            commandLineArgs = "--disable-gpu-compositing --enable-features=WebRTCPipeWireCapturer";
          }
        )
      )
      |> prev.lib.listToAttrs
    );

  # Fucking shit ass electron bullshit password store.
  # Only selects gnome-libsecret if running from a set of hardcoded sessions, dumb fucking shit.
  # Honestly who the fuck thought that was a good detection method for a password store, and why the fuck is it even a thing in 2026.
  electronPasswordStoreFixes =
    _: prev:
    [
      "vscode"
      "obsidian"
      "hermes-desktop"
    ]
    |> map (
      name:
      prev.lib.nameValuePair name (
        prev.${name}.override {
          commandLineArgs = "--password-store=gnome-libsecret";
        }
      )
    )
    |> prev.lib.listToAttrs;
}
