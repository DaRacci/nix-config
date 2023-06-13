# Custom packages, that can be defined similarly to ones from nixpkgs
# You can build them using 'nix build .#example' or (legacy) 'nix-build -A example'

{ pkgs ? (import ../nixpkgs.nix) { } }: {
  # nixos-conf-editor = pkgs.callPackage ./nixos-conf-editor { };
  # nix-software-center = pkgs.callPackage ./nix-software-center { };
  # protonup-rs = pkgs.callPackage ./protonup-rs { };
  ficsit-cli = pkgs.callPackage ./ficsit-cli { };
  noise-supression = pkgs.callPackage ./noise-suppression-for-voice { };
  eltrafico = pkgs.callPackage ./eltrafico { };
  # coolercontrol = pkgs.callPackage ./coolercontrol { };

  idea-community = pkgs.buildFHSEnv {
    name = "idea";
    targetPkgs = pkgs: (with pkgs; [ jetbrains.idea-community ]);
    runScript = "idea-community";
  };
}
