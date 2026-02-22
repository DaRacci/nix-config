# Using a NixOS Module from a Separate Fork of Nixpkgs

The best option is if the PR only introduces a single file to add this as a input to `flake/nixos/flake.nix` to avoid having an entire additional nixpkgs input.

Example:

```nix
{
  inputs = {
    desired-module = {
      url = "https://raw.githubusercontent.com/<owner>/<repo>/refs/heads/<branch>/nixos/<path-to-module>";
      flake = false;
      type = "file";
    };
  };
}
```

This can now be imported like any other module on the host like so:

```nix
{
  imports = [
    inputs.desired-module
  ];
}
```
