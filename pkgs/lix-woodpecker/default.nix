{
  inputs,
  pkgs,
  ...
}:

let
  inherit (pkgs.stdenv.hostPlatform) system;
  inherit (inputs.nix2container.packages.${system}) nix2container;
  buildLixImage = import "${inputs.lix}/docker.nix";
in
buildLixImage {
  inherit pkgs nix2container;
  name = "registry.racci.dev/lix-woodpecker";
  maxLayers = 128;

  extraPkgs = with pkgs; [
    gawk
    jq
    gnupg
    attic-client
  ];

  nixConf = rec {
    extra-experimental-features = "nix-command flakes pipe-operator pipe-operators";
    accept-flake-config = "true";

    trusted-substituters = "https://cache.racci.dev/global";
    extra-trusted-public-keys = "global:OKNSxDYKp8Q8Tr5/5Bc7CYVSfvdFQV0dMhpG0fOAG0k=";
    extra-substituters = trusted-substituters;
    netrc-file = "/tmp/netrc"; # For use with the setup-attic.nu ci script.
  };
}
