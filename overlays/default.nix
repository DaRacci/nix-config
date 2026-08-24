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
      mcpo = (prev.python3Packages.callPackage inputs.mcpo { }).overridePythonAttrs (old: {
        patches = (old.patches or [ ]) ++ [
          ./patches/mcpo-union-repr-compat.patch
        ];
      });

      hermes-agent =
        let
          lock = builtins.fromJSON (builtins.readFile ../flake/nixos/flake.lock);
          haLocked = lock.nodes.hermes-agent.locked;
          haFlake = builtins.getFlake "github:${haLocked.owner}/${haLocked.repo}/${haLocked.rev}";
          hermesAgentSrc = prev.applyPatches {
            name = "hermes-agent-patched";
            src = haFlake.outPath;
            patches = [
              # TODO:https://github.com/NousResearch/hermes-agent/pull/48637
              (prev.fetchpatch {
                url = "https://github.com/NousResearch/hermes-agent/pull/48637.patch";
                excludes = [ "tests/tools/test_lazy_deps_managed.py" ];
                hash = "sha256-ou6mVPoOK/au67xsXxOYtwM+aVKjBkgCVnY2coXhsu8=";
              })
              # TODO:https://github.com/NousResearch/hermes-agent/pull/87820
              (prev.fetchpatch {
                url = "https://github.com/NousResearch/hermes-agent/pull/87820.patch";
                hash = "sha256-FgQc5xwMz3+bhX0yEqjh7kky2lepuUv8xg9g0FCgN74=";
              })
              # TODO:https://github.com/NousResearch/hermes-agent/pull/93896
              (prev.fetchpatch {
                url = "https://github.com/NousResearch/hermes-agent/pull/93896.patch";
                hash = "sha256-5BtZ0IVZwS44rkstSb+vUIje0aVtCcnm9KMr8jauYtY=";
              })
            ];
          };
        in
        final.callPackage (hermesAgentSrc + "/nix/hermes-agent.nix") {
          uv2nix = haFlake.inputs.uv2nix;
          pyproject-nix = haFlake.inputs.pyproject-nix;
          pyproject-build-systems = haFlake.inputs.pyproject-build-systems;
          npm-lockfile-fix =
            haFlake.inputs.npm-lockfile-fix.packages.${final.stdenv.hostPlatform.system}.default;
          rev = haLocked.rev or null;
        };

      lm_sensors-perlless = prev.lm_sensors.overrideAttrs (oldAttrs: {
        buildInputs = oldAttrs.buildInputs |> (lib.remove prev.perl);
      });

      fastembed-hermes = prev.python312Packages.fastembed.overridePythonAttrs (old: {
        dependencies = builtins.filter (
          dep:
          let
            name = lib.getName dep;
          in
          # Hermes uv2nix env already has these deps and complains about colisions.
          !(builtins.any (n: lib.hasInfix n name) [
            "huggingface-hub"
            "numpy"
            "onnxruntime"
            "pillow"
            "requests"
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
      withVencord = true;
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
