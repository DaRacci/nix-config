_: {
  imports = [
    ./backup.nix
    ./persistence.nix
  ];

  options.user.files = { };

  config = { };
}
