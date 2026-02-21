{
  pkgs,
  ...
}:
{
  imports = [
    ./list-ephemeral.nix
  ];

  options.programs = { };

  config = {
    home.packages = [
      pkgs.folder-diff
      pkgs.image-compressor
    ];
  };
}
