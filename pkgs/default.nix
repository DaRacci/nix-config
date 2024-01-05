# Custom packages, that can be defined similarly to ones from nixpkgs
# You can build them using 'nix build .#example' or (legacy) 'nix-build -A example'

{ system, nixpkgs, getchoo }:
let pkgs = nixpkgs.legacyPackages.${system}; in {
  protonup-rs = pkgs.callPackage ./protonup-rs { };
  ficsit-cli = pkgs.callPackage ./ficsit-cli { };
  noise-supression = pkgs.callPackage ./noise-suppression-for-voice { };

  inherit (getchoo.packages.${builtins.currentSystem}) modrinth-app;

  # nixcloud = nixos-generators.nixosGenerate {
  #   inherit (mkRawConfiguration "nixcloud" { inherit system; }) system modules specialArgs;

  #   format = "proxmox-lxc";
  # };
}
