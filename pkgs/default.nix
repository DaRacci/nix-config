# Custom packages, that can be defined similarly to ones from nixpkgs
# You can build them using 'nix build .#example' or (legacy) 'nix-build -A example'

{ pkgs }: {
  protonup-rs = pkgs.callPackage ./protonup-rs { };
  ficsit-cli = pkgs.callPackage ./ficsit-cli { };
  noise-suppression = pkgs.callPackage ./noise-suppression-for-voice { };

  copy-to-proxmox = pkgs.callPackage ./copy-to-proxmox { };
  create-proxmox-container = pkgs.callPackage ./create-proxmox-container { };
}
