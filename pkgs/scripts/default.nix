{
  pkgs,
  lib,
}:
let
  inherit (lib.mine.packages) writeNuApplication;
  inherit (pkgs)
    file
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

  image-compressor = writers.writePython3Bin "image-compressor" {
    libraries = [
      python3Packages.pillow
      python3Packages.rich
      python3Packages.python-magic
    ];

    flakeIgnore = [
      "E265"
      "E501"
      "W503"
    ];

    makeWrapperArgs = [
      "--prefix"
      "PATH"
      ":"
      (lib.makeBinPath [
        imagemagick
        file
      ])
    ];
  } (builtins.readFile ./image-compressor.py);

}
