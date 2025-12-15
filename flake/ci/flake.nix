{
  description = ''
    Private inputs for CI purposes. These are used by the top level
    flake in the `ci` partition, but do not appear in consumers' lock files.
  '';

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    nix-github-actions = {
      url = "github:nix-community/nix-github-actions";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = _: { };
}
