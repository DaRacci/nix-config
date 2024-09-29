{ pkgs, ... }: {
  imports = [
    ./browser.nix
    ./calendar.nix
    ./email.nix
    ./files.nix
    ./image-editor.nix
    ./media.nix
    ./notes.nix
    ./recording.nix
    ./social.nix
    ./streamdeck.nix
    ./terminal.nix
  ];

  home.packages = with pkgs; [
    toybox
  ];
}
