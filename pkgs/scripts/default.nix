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

}
