{ pkgs, ... }: {
  home.packages = with pkgs.unstable; [ lapce ];

  home.persistent."/persist/home/racci".directories = [
    ".config/lapce-stable/lapce.db"
  ];

  # home.file.".config/lapce-stable/settings.toml".text = ''
  # [core]
  # color-theme = "Lapce Dark"
  # modal = false

  # [ui]
  # font-family = "Fira Sans"
  # font-size = 20

  # [lapce-nix]
  # lsp-path = ${pkgs.nil}/bin/nix-lsp
  # '';

  # home.file.".config/lapce-stable/keymaps.toml".text = ''
  # '';
}