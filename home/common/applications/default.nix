{ pkgs, ... }: {
  imports = [
    ./cooling.nix
    ./email.nix
    ./image-editor.nix
    ./notes.nix
    ./recording.nix
  ];

  home.packages = with pkgs; [ okteta ];
}
