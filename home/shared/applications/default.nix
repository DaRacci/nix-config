{ pkgs, ... }: {
  imports = [
    ./browser.nix
    ./email.nix
    ./files.nix
    ./image-editor.nix
    ./media.nix
    ./notes.nix
    ./recording.nix
    ./social.nix
  ];

  home.packages = with pkgs; [
    toybox
  ];
}
