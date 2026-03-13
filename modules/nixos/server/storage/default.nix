{
  ...
}:
{
  imports = [
    ./bucket.nix
    ./seaweedfs.nix
  ];

  options.server.storage = { };

  config = { };
}
