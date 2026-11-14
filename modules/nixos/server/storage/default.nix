{
  ...
}:
{
  imports = [
    ./bucket.nix
    ./seaweedfs
  ];

  options.server.storage = { };

  config = { };
}
