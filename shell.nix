# Shell for bootstrapping flake-enabled nix and home-manager
# You can enter it through 'nix develop'

{ pkgs ? (import ./nixpkgs.nix) { } }:
pkgs.mkShell {
  # Enable experimental features without having to specify the argument
  NIX_CONFIG = "extra-experimental-features = nix-command flakes repl-flake";
  nativeBuildInputs = with pkgs; [
    nix
    home-manager
    git

    # For Secure Boot Debugging
    sbctl

    # For sops-nix
    sops
    ssh-to-age
    age
  ];
}
