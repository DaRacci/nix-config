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
      mcpo = prev.python3Packages.callPackage inputs.mcpo { };

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
              ./patches/hermes-agent-pr-48637-lazy-deps.patch
              # TODO:https://github.com/NousResearch/hermes-agent/pull/53202
              ./patches/hermes-agent-pr-61443-node-headers-hash.patch
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
      # withVencord = true;
      nss = final.nss_latest;
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
      (_self: super: {
        #TODO:Remove once nixpkgs kernel-zen is updated to 7.1 which includes the fix i wanted.
        universal-pidff = super.universal-pidff.overrideAttrs (_old: {
          version = "unstable-2026-06-02";
          src = prev.fetchFromGitHub {
            owner = "JacKeTUs";
            repo = "universal-pidff";
            rev = "595c65bb23ad824cb6d8dedb1d74123f622de1cc";
            hash = "sha256-0eXrCZSHrD5OkrqeYMcuV20us2Hl6d48dIvrZi/GY8c=";
          };
        });
      })
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
