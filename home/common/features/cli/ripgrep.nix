{ pkgs, ... }: rec {
  programs.ripgrep = {
    enable = true;
    package = pkgs.ripgrep;

    arguments = [ ];
  };

  home.shellAliases.grep = "rg";
  programs.nushell.grep = home.shellAliases.grep;
}
