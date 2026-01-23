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

  extraPkgs = with pkgs; [
    gawk
    jq
    gnupg
  ];

  nixConf = {
    extra-experimental-features = "nix-command flakes pipe-operator";
  };
}
