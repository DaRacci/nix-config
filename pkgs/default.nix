# Custom packages, that can be defined similarly to ones from nixpkgs
# You can build them using 'nix build .#example' or (legacy) 'nix-build -A example'

{ system, pkgs, getchoo }: {
  protonup-rs = pkgs.callPackage ./protonup-rs { };
  ficsit-cli = pkgs.callPackage ./ficsit-cli { };
  noise-supression = pkgs.callPackage ./noise-suppression-for-voice { };

  inherit (getchoo.packages.${builtins.currentSystem}) modrinth-app;

  # nixcloud = nixos-generators.nixosGenerate {
  #   inherit (mkRawConfiguration "nixcloud" { inherit system; }) system modules specialArgs;

  #   format = "proxmox-lxc";
  # };

  # TODO :: Remove this override when the patch is either updated to removed from the builder
  # https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/by-name/vi/vinegar/package.nix
  vinegar = pkgs.callPackage ./vinegar.nix { };
}
