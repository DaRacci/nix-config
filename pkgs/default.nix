# Custom packages, that can be defined similarly to ones from nixpkgs
# You can build them using 'nix build .#example' or (legacy) 'nix-build -A example'

{ pkgs, getchoo }: {
  protonup-rs = pkgs.callPackage ./protonup-rs { };
  ficsit-cli = pkgs.callPackage ./ficsit-cli { };
  noise-supression = pkgs.callPackage ./noise-suppression-for-voice { };

  inherit (getchoo.packages.${builtins.currentSystem}) modrinth-app;
}
