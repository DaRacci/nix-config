# Shell for bootstrapping flake-enabled nix and home-manager
# You can enter it through 'nix develop'

{ pkgs ? (import ./nixpkgs.nix) { } }: {
  default = pkgs.mkShell {
    # Enable experimental features without having to specify the argument
    NIX_CONFIG = "extra-experimental-features = nix-command flakes repl-flake";
    nativeBuildInputs = with pkgs; [
      nix
      home-manager
      git

      sops
      ssh-to-age
      age
    ];
  };
}
