# Custom packages, that can be defined similarly to ones from nixpkgs
# You can build them using 'nix build .#example' or (legacy) 'nix-build -A example'

{ pkgs ? (import ../nixpkgs.nix) { } }: {
  # nixos-conf-editor = pkgs.callPackage ./nixos-conf-editor { };
  # nix-software-center = pkgs.callPackage ./nix-software-center { };

  # example = pkgs.callPackage ./example { };
}
