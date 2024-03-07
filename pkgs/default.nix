# Custom packages, that can be defined similarly to ones from nixpkgs
# You can build them using 'nix build .#example' or (legacy) 'nix-build -A example'

{ system, pkgs, getchoo }: {
  protonup-rs = pkgs.callPackage ./protonup-rs { };
  ficsit-cli = pkgs.callPackage ./ficsit-cli { };
  noise-supression = pkgs.callPackage ./noise-suppression-for-voice { };

  # nixcloud = nixos-generators.nixosGenerate {
  #   inherit (mkRawConfiguration "nixcloud" { inherit system; }) system modules specialArgs;

  #   format = "proxmox-lxc";
  # };
}
