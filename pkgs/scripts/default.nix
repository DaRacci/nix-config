{
  pkgs,
  lib,
}:
let
  inherit (lib.mine.packages) writeNuApplication;
  inherit (pkgs)
    ffmpeg-headless
    file
    handbrake
    imagemagick
    python3Packages
    rsync
    uutils-findutils
    writers
    ;
in
{
  colour-picker = pkgs.callPackage ./colour-picker { };

  folder-diff = writeNuApplication {
    inherit pkgs;
    sourceRoot = ./.;
    name = "folder-diff";
    runtimeInputs = [
      rsync
      uutils-findutils
    ];
  };

  compressor = writers.writePython3Bin "compressor" {
    libraries = [
      python3Packages.pillow
      python3Packages.rich
      python3Packages.python-magic
    ];

    flakeIgnore = [
      "E203"
      "E265"
      "E501"
      "W503"
    ];

    makeWrapperArgs = [
      "--prefix"
      "PATH"
      ":"
      (lib.makeBinPath [
        ffmpeg-headless
        handbrake
        imagemagick
        file
      ])
    ];
  } (builtins.readFile ./compressor.py);

  ocr-region = pkgs.callPackage ./ocr-region { };
  orca-slicer-git-sync = pkgs.callPackage ./orca-slicer-git-sync { };
  screenshot = pkgs.callPackage ./screenshot { };
  ssh-relay = pkgs.callPackage ./ssh-relay { };
  ssh-to-age-keys = pkgs.callPackage ./ssh-to-age-keys { };
  sunshine-tools = pkgs.callPackage ./sunshine-tools { };
  swfs-mount-hooks = pkgs.callPackage ./swfs-mount-hooks { };
  virtualisation-tools = pkgs.callPackage ./virtualisation-tools { };
  wait-for-io-tools = pkgs.callPackage ./wait-for-io-tools { };
  wlprop = pkgs.callPackage ./wlprop { };
}
